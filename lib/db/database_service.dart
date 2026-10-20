import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite/sqflite.dart'
    show databaseFactory, OpenDatabaseOptions, Database;

import '../models/patient.dart';
import '../models/visit.dart';
import '../models/lab_test.dart';
import '../models/panel.dart';
import '../models/panel_test.dart';

/// Default clinic info — used to seed the settings table on first run.
const String _defaultClinicName = 'ALI AMJAD DIAGNOSTIC CENTER';
const String _defaultClinicTagline = 'Imaging & Lab Services';
const String _defaultClinicAddress = 'Ground Floor, Main Road, Jand';
const String _defaultClinicPhone = '051 111 000 432';

/// A tiny value object for clinic info.
class ClinicInfo {
  final String name;
  final String tagline;
  final String address;
  final String phone;

  const ClinicInfo({
    required this.name,
    required this.tagline,
    required this.address,
    required this.phone,
  });
}

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;
  String? _dbPath;

  Future<void> init() async {
    if (_db != null) return;

    final dir = await getApplicationSupportDirectory();
    _dbPath = p.join(dir.path, 'cliniclab.db');

    _db = await databaseFactory.openDatabase(
      _dbPath!,
      options: OpenDatabaseOptions(
        version: 5, // Phase: Settings feature
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA busy_timeout = 5000');
        },
        onCreate: (db, version) async {
          await _createTables(db);
          await _seedSettings(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 4) {
            // Phase 3: add price + invoice fields.
            try {
              await db.execute(
                  'ALTER TABLE panel_tests ADD COLUMN price REAL DEFAULT 0');
            } catch (_) {}
            try {
              await db.execute(
                  'ALTER TABLE tests ADD COLUMN price REAL DEFAULT 0');
            } catch (_) {}
            try {
              await db.execute(
                  'ALTER TABLE visits ADD COLUMN discount REAL DEFAULT 0');
            } catch (_) {}
            try {
              await db.execute(
                  'ALTER TABLE visits ADD COLUMN amount_received REAL DEFAULT 0');
            } catch (_) {}
            try {
              await db.execute(
                  "ALTER TABLE visits ADD COLUMN payment_mode TEXT DEFAULT 'Cash'");
            } catch (_) {}
            try {
              await db.execute(
                  "ALTER TABLE visits ADD COLUMN invoice_notes TEXT DEFAULT ''");
            } catch (_) {}
          }
          if (oldVersion < 5) {
            // Settings feature: create settings table + seed defaults.
            await db.execute('''
              CREATE TABLE IF NOT EXISTS settings(
                key TEXT PRIMARY KEY,
                value TEXT
              )
            ''');
            await _seedSettings(db);
          }
        },
      ),
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age TEXT,
        gender TEXT,
        phone TEXT,
        address TEXT,
        date_added TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS visits(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        pin TEXT NOT NULL UNIQUE,
        visit_date TEXT NOT NULL,
        referred_by TEXT,
        created_at TEXT,
        discount REAL DEFAULT 0,
        amount_received REAL DEFAULT 0,
        payment_mode TEXT DEFAULT 'Cash',
        invoice_notes TEXT DEFAULT '',
        FOREIGN KEY(patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_visits_patient ON visits(patient_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_visits_date ON visits(visit_date)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tests(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visit_id INTEGER NOT NULL,
        section TEXT,
        test_name TEXT NOT NULL,
        result TEXT,
        unit TEXT,
        normal_range TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'Pending',
        reporting_time TEXT,
        price REAL DEFAULT 0,
        FOREIGN KEY(visit_id) REFERENCES visits(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tests_visit ON tests(visit_id)');

    await _createPanelTables(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> _createPanelTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS panels(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS panel_tests(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        panel_id INTEGER NOT NULL,
        section TEXT,
        test_name TEXT NOT NULL,
        unit TEXT,
        normal_range TEXT,
        display_order INTEGER,
        price REAL DEFAULT 0,
        FOREIGN KEY(panel_id) REFERENCES panels(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_panel_tests_panel ON panel_tests(panel_id)');
  }

  /// Insert default clinic info rows if they don't exist yet.
  Future<void> _seedSettings(Database db) async {
    final defaults = {
      'clinic_name': _defaultClinicName,
      'clinic_tagline': _defaultClinicTagline,
      'clinic_address': _defaultClinicAddress,
      'clinic_phone': _defaultClinicPhone,
    };
    for (final entry in defaults.entries) {
      await db.insert(
        'settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
      );
    }
  }

  Database get db {
    if (_db == null) {
      throw StateError('Database not initialized. Call init() first.');
    }
    return _db!;
  }

  Future<String> getDatabasePath() async {
    if (_dbPath != null) return _dbPath!;
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'cliniclab.db');
  }

  // ===========================================================================
  // SETTINGS (clinic info, etc.)
  // ===========================================================================

  Future<String?> getSetting(String key) async {
    final rows = await db
        .query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<ClinicInfo> getClinicInfo() async {
    final name = await getSetting('clinic_name') ?? _defaultClinicName;
    final tagline = await getSetting('clinic_tagline') ?? _defaultClinicTagline;
    final address = await getSetting('clinic_address') ?? _defaultClinicAddress;
    final phone = await getSetting('clinic_phone') ?? _defaultClinicPhone;
    return ClinicInfo(
      name: name,
      tagline: tagline,
      address: address,
      phone: phone,
    );
  }

  Future<void> saveClinicInfo(ClinicInfo info) async {
    await setSetting('clinic_name', info.name);
    await setSetting('clinic_tagline', info.tagline);
    await setSetting('clinic_address', info.address);
    await setSetting('clinic_phone', info.phone);
  }

  // ===========================================================================
  // BACKUP / RESTORE
  // ===========================================================================

  /// Copy the current DB file to [destinationPath].
  /// Ensures any pending writes are flushed first.
  Future<void> backupDatabase(String destinationPath) async {
    // Force a checkpoint so all data is on disk in the .db file.
    try {
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {
      // Not using WAL — ignore.
    }

    final srcPath = await getDatabasePath();
    final src = File(srcPath);
    if (!await src.exists()) {
      throw StateError('Database file not found.');
    }

    // Copy bytes to the destination.
    final dest = File(destinationPath);
    await dest.parent.create(recursive: true);
    await src.copy(destinationPath);
  }

  /// Close the current DB, replace the file with [sourcePath],
  /// then re-open.
  Future<void> restoreDatabase(String sourcePath) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw StateError('Backup file not found.');
    }

    // Validate that the source is a valid SQLite file (basic sanity check).
    final bytes = await src.openRead(0, 16).first;
    const sqliteHeader = 'SQLite format 3\u0000';
    final headerStr = String.fromCharCodes(bytes.take(16));
    if (headerStr != sqliteHeader) {
      throw StateError('Selected file is not a valid database backup.');
    }

    // Close the current DB.
    final currentPath = await getDatabasePath();
    await _db?.close();
    _db = null;

    // Overwrite the DB file with the backup.
    final dest = File(currentPath);
    if (await dest.exists()) {
      await dest.delete();
    }
    await src.copy(currentPath);

    // Delete any leftover WAL / SHM files.
    final wal = File('$currentPath-wal');
    final shm = File('$currentPath-shm');
    if (await wal.exists()) await wal.delete();
    if (await shm.exists()) await shm.delete();

    // Reopen the DB.
    await init();
  }

  /// Gracefully close the DB (used before restoring).
  Future<void> closeDatabase() async {
    await _db?.close();
    _db = null;
  }

  // ===========================================================================
  // PATIENTS
  // ===========================================================================

  Future<List<Patient>> getPatients({String query = ''}) async {
    List<Map<String, dynamic>> rows;
    if (query.isEmpty) {
      rows = await db.query('patients', orderBy: 'date_added DESC');
    } else {
      final q = '%${query.toLowerCase()}%';
      rows = await db.query(
        'patients',
        where: 'LOWER(name) LIKE ? OR LOWER(phone) LIKE ?',
        whereArgs: [q, q],
        orderBy: 'date_added DESC',
      );
    }
    return rows.map((r) => Patient.fromMap(r)).toList();
  }

  Future<int> insertPatient(Patient patient) async {
    return await db.insert('patients', patient.toMap());
  }

  Future<void> updatePatient(Patient patient) async {
    if (patient.id == null) {
      throw ArgumentError('Cannot update a patient without an id.');
    }
    await db.update('patients', patient.toMap(),
        where: 'id = ?', whereArgs: [patient.id]);
  }

  Future<void> deletePatient(int id) async {
    final visits = await db.query('visits',
        columns: ['id'], where: 'patient_id = ?', whereArgs: [id]);
    for (final v in visits) {
      final vid = v['id'] as int;
      await db.delete('tests', where: 'visit_id = ?', whereArgs: [vid]);
    }
    await db.delete('visits', where: 'patient_id = ?', whereArgs: [id]);
    await db.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  // ===========================================================================
  // VISITS
  // ===========================================================================

  Future<String> generatePin({DateTime? at}) async {
    final now = at ?? DateTime.now();
    final yy = now.year.toString().substring(2);
    final mm = now.month.toString().padLeft(2, '0');
    final prefix = '$yy$mm-';

    // Find the highest existing number for this month's prefix.
    final result = await db.rawQuery(
      "SELECT pin FROM visits WHERE pin LIKE ? ORDER BY pin DESC LIMIT 1",
      ['$prefix%'],
    );

    int nextNumber = 1;
    if (result.isNotEmpty) {
      final lastPin = result.first['pin'] as String? ?? '';
      // lastPin looks like "2610-000005" — take the part after the dash.
      final parts = lastPin.split('-');
      if (parts.length == 2) {
        final lastNumber = int.tryParse(parts[1]) ?? 0;
        nextNumber = lastNumber + 1;
      }
    }

    final next = nextNumber.toString().padLeft(6, '0');
    return '$prefix$next';
  }

  Future<int> insertVisit(Visit visit) async {
    return await db.insert('visits', visit.toMap());
  }

  Future<void> updateVisit(Visit visit) async {
    await db.update('visits', visit.toMap(),
        where: 'id = ?', whereArgs: [visit.id]);
  }

  Future<void> updateVisitInvoice({
    required int visitId,
    required double discount,
    required double amountReceived,
    required String paymentMode,
    required String invoiceNotes,
  }) async {
    await db.update(
      'visits',
      {
        'discount': discount,
        'amount_received': amountReceived,
        'payment_mode': paymentMode,
        'invoice_notes': invoiceNotes,
      },
      where: 'id = ?',
      whereArgs: [visitId],
    );
  }

  Future<void> deleteVisit(int visitId) async {
    await db.delete('tests', where: 'visit_id = ?', whereArgs: [visitId]);
    await db.delete('visits', where: 'id = ?', whereArgs: [visitId]);
  }

  Future<List<Visit>> getVisitsForPatient(int patientId) async {
    final rows = await db.query('visits',
        where: 'patient_id = ?',
        whereArgs: [patientId],
        orderBy: 'visit_date DESC');
    return rows.map((r) => Visit.fromMap(r)).toList();
  }

  Future<List<Visit>> getVisits({int? patientId}) async {
    List<Map<String, dynamic>> rows;
    if (patientId == null) {
      rows = await db.query('visits', orderBy: 'visit_date DESC');
    } else {
      rows = await db.query('visits',
          where: 'patient_id = ?',
          whereArgs: [patientId],
          orderBy: 'visit_date DESC');
    }
    return rows.map((r) => Visit.fromMap(r)).toList();
  }

  Future<Visit?> getVisit(int visitId) async {
    final rows =
    await db.query('visits', where: 'id = ?', whereArgs: [visitId], limit: 1);
    if (rows.isEmpty) return null;
    return Visit.fromMap(rows.first);
  }

  /// True when subtotal - discount <= amount_received and net > 0.
  Future<bool> isVisitPaid(int visitId) async {
    final visit = await getVisit(visitId);
    if (visit == null) return false;

    final subtotalResult = await db.rawQuery(
      'SELECT COALESCE(SUM(price), 0) AS s FROM tests WHERE visit_id = ?',
      [visitId],
    );
    final subtotalRaw = subtotalResult.first['s'];
    final subtotal = subtotalRaw is num ? subtotalRaw.toDouble() : 0.0;
    final net = (subtotal - visit.discount).clamp(0.0, double.infinity);
    return visit.amountReceived >= net && net > 0;
  }

  // ===========================================================================
  // TESTS
  // ===========================================================================

  Future<int> insertTest(LabTest test) async {
    return await db.insert('tests', test.toMap());
  }

  Future<void> updateTest(LabTest test) async {
    await db.update('tests', test.toMap(),
        where: 'id = ?', whereArgs: [test.id]);
  }

  Future<void> deleteTest(int testId) async {
    await db.delete('tests', where: 'id = ?', whereArgs: [testId]);
  }

  Future<void> updateAllTestsStatus(int visitId, String status) async {
    final reportingTime = status.toLowerCase() == 'final'
        ? DateTime.now().toString().substring(0, 16)
        : '';
    await db.update(
      'tests',
      {'status': status, 'reporting_time': reportingTime},
      where: 'visit_id = ?',
      whereArgs: [visitId],
    );
  }

  Future<List<LabTest>> getTestsForVisit(int visitId) async {
    final rows = await db.query('tests',
        where: 'visit_id = ?',
        whereArgs: [visitId],
        orderBy: 'section ASC, id ASC');
    return rows.map((r) => LabTest.fromMap(r)).toList();
  }

  Future<int> countTestsForVisit(int visitId) async {
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM tests WHERE visit_id = ?',
      [visitId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // ===========================================================================
  // PANELS
  // ===========================================================================

  Future<List<Panel>> getPanels() async {
    final rows = await db.query('panels', orderBy: 'name ASC');
    return rows.map((r) => Panel.fromMap(r)).toList();
  }

  Future<Panel?> getPanel(int panelId) async {
    final rows =
    await db.query('panels', where: 'id = ?', whereArgs: [panelId], limit: 1);
    if (rows.isEmpty) return null;
    return Panel.fromMap(rows.first);
  }

  Future<int> insertPanel(Panel panel) async {
    return await db.insert('panels', panel.toMap());
  }

  Future<void> updatePanel(Panel panel) async {
    await db.update('panels', panel.toMap(),
        where: 'id = ?', whereArgs: [panel.id]);
  }

  Future<void> deletePanel(int panelId) async {
    await db.delete('panel_tests', where: 'panel_id = ?', whereArgs: [panelId]);
    await db.delete('panels', where: 'id = ?', whereArgs: [panelId]);
  }

  Future<List<PanelTest>> getPanelTests(int panelId) async {
    final rows = await db.query('panel_tests',
        where: 'panel_id = ?',
        whereArgs: [panelId],
        orderBy: 'display_order ASC, id ASC');
    return rows.map((r) => PanelTest.fromMap(r)).toList();
  }

  Future<int> insertPanelTest(PanelTest test) async {
    return await db.insert('panel_tests', test.toMap());
  }

  Future<void> updatePanelTest(PanelTest test) async {
    await db.update('panel_tests', test.toMap(),
        where: 'id = ?', whereArgs: [test.id]);
  }

  Future<void> deletePanelTest(int testId) async {
    await db.delete('panel_tests', where: 'id = ?', whereArgs: [testId]);
  }

  Future<int> countTestsInPanel(int panelId) async {
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM panel_tests WHERE panel_id = ?',
      [panelId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<double> sumPanelPrice(int panelId) async {
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(price), 0) AS s FROM panel_tests WHERE panel_id = ?',
      [panelId],
    );
    final v = r.first['s'];
    if (v is num) return v.toDouble();
    return 0;
  }

  // ===========================================================================
  // DASHBOARD STATS
  // ===========================================================================

  Future<int> countPatients() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM patients');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> countVisits() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM visits');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> countTests() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM tests');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> countVisitsSince(DateTime since) async {
    final iso = since.toIso8601String().substring(0, 10);
    final r = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM visits WHERE visit_date >= ?",
      [iso],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  Future<List<Visit>> getRecentVisits({int limit = 5}) async {
    final rows =
    await db.query('visits', orderBy: 'visit_date DESC', limit: limit);
    return rows.map((r) => Visit.fromMap(r)).toList();
  }

  Future<List<Patient>> getRecentPatients({int limit = 5}) async {
    final rows =
    await db.query('patients', orderBy: 'date_added DESC', limit: limit);
    return rows.map((r) => Patient.fromMap(r)).toList();
  }
}