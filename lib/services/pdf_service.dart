import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../db/database_service.dart';
import '../models/lab_test.dart';
import '../models/patient.dart';
import '../models/visit.dart';

class PdfService {
  // ===========================================================================
  // REPORT — public API
  // ===========================================================================

  static Future<void> printVisitReport({
    required Patient patient,
    required Visit visit,
    required List<LabTest> tests,
  }) async {
    final clinic = await DatabaseService.instance.getClinicInfo();
    final doc = _buildVisitDocument(
      clinic: clinic,
      patient: patient,
      visit: visit,
      tests: tests,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Report_${visit.pin}',
    );
  }

  static Future<void> printSingleTest({
    required Patient patient,
    required Visit visit,
    required LabTest test,
  }) async {
    final clinic = await DatabaseService.instance.getClinicInfo();
    final doc = _buildVisitDocument(
      clinic: clinic,
      patient: patient,
      visit: visit,
      tests: [test],
    );
    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Test_${test.testName}_${visit.pin}',
    );
  }

  static Future<List<int>> buildVisitReportBytes({
    required Patient patient,
    required Visit visit,
    required List<LabTest> tests,
  }) async {
    final clinic = await DatabaseService.instance.getClinicInfo();
    final doc = _buildVisitDocument(
      clinic: clinic,
      patient: patient,
      visit: visit,
      tests: tests,
    );
    return await doc.save();
  }

  static Future<File> saveVisitReportPdf({
    required Patient patient,
    required Visit visit,
    required List<LabTest> tests,
  }) async {
    final bytes = await buildVisitReportBytes(
      patient: patient,
      visit: visit,
      tests: tests,
    );
    final dir = await getTemporaryDirectory();
    final safePin = visit.pin.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final file = File('${dir.path}/Report_$safePin.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<String> saveVisitReportToDownloads({
    required Patient patient,
    required Visit visit,
    required List<LabTest> tests,
  }) async {
    final bytes = await buildVisitReportBytes(
      patient: patient,
      visit: visit,
      tests: tests,
    );
    return _writeToDownloads(bytes, 'Report_${_safePin(visit.pin)}.pdf');
  }

  // ===========================================================================
  // INVOICE — public API
  // ===========================================================================

  static Future<void> printInvoice({
    required Patient patient,
    required Visit visit,
    required List<LabTest> tests,
  }) async {
    final clinic = await DatabaseService.instance.getClinicInfo();
    final doc = _buildInvoiceDocument(
      clinic: clinic,
      patient: patient,
      visit: visit,
      tests: tests,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Invoice_${visit.pin}',
    );
  }

  static Future<List<int>> buildInvoiceBytes({
    required Patient patient,
    required Visit visit,
    required List<LabTest> tests,
  }) async {
    final clinic = await DatabaseService.instance.getClinicInfo();
    final doc = _buildInvoiceDocument(
      clinic: clinic,
      patient: patient,
      visit: visit,
      tests: tests,
    );
    return await doc.save();
  }

  static Future<String> saveInvoiceToDownloads({
    required Patient patient,
    required Visit visit,
    required List<LabTest> tests,
  }) async {
    final bytes = await buildInvoiceBytes(
      patient: patient,
      visit: visit,
      tests: tests,
    );
    return _writeToDownloads(bytes, 'Invoice_${_safePin(visit.pin)}.pdf');
  }

  // ===========================================================================
  // Shared helpers
  // ===========================================================================

  static String _safePin(String pin) =>
      pin.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  static Future<String> _writeToDownloads(
      List<int> bytes, String fileName) async {
    Directory targetDir;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final downloads = await getDownloadsDirectory();
      targetDir = downloads ?? await getApplicationDocumentsDirectory();
    } else {
      targetDir = await getApplicationDocumentsDirectory();
    }

    final target = File('${targetDir.path}${Platform.pathSeparator}$fileName');
    final finalPath = await _uniquePath(target);
    await File(finalPath).writeAsBytes(bytes);
    return finalPath;
  }

  static Future<String> _uniquePath(File file) async {
    if (!await file.exists()) return file.path;
    final dir = file.parent.path;
    final baseName = file.uri.pathSegments.last.replaceAll('.pdf', '');
    for (int i = 2; i < 1000; i++) {
      final candidate =
      File('$dir${Platform.pathSeparator}$baseName ($i).pdf');
      if (!await candidate.exists()) return candidate.path;
    }
    return file.path;
  }

  // ===========================================================================
  // REPORT — document builder
  // ===========================================================================

  static pw.Document _buildVisitDocument({
    required ClinicInfo clinic,
    required Patient patient,
    required Visit visit,
    required List<LabTest> tests,
  }) {
    final doc = pw.Document();

    final grouped = <String, List<LabTest>>{};
    for (final t in tests) {
      final key = t.section.isEmpty ? 'General' : t.section;
      grouped.putIfAbsent(key, () => []).add(t);
    }

    final comments = tests
        .map((t) => t.notes.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    final refNo = visit.pin;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(60, 120, 30, 40),
        header: (context) => _buildReportHeader(refNo),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 6),
          _buildPatientBlock(patient: patient, visit: visit),
          pw.SizedBox(height: 12),
          if (grouped.length == 1)
            _buildSingleSectionTitle(grouped.keys.first)
          else
            pw.SizedBox.shrink(),
          pw.SizedBox(height: 6),
          ...grouped.entries.map((e) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (grouped.length > 1) ...[
                  _buildSectionHeading(e.key),
                  pw.SizedBox(height: 6),
                ],
                _buildTestTable(e.value),
                pw.SizedBox(height: 14),
              ],
            );
          }),
          if (comments.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Comments:',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                comments.join('\n\n'),
                style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
              ),
            ),
          ],
        ],
      ),
    );

    return doc;
  }

  static pw.Widget _buildReportHeader(String refNo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Ref #$refNo',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1.2, color: PdfColors.blue900),
      ],
    );
  }
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.SizedBox(height: 3),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated: ${DateTime.now().toString().substring(0, 16)}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPatientBlock({
    required Patient patient,
    required Visit visit,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
        color: PdfColors.grey50,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoPair('Name', patient.name),
                pw.SizedBox(height: 5),
                _infoPair('Phone',
                    patient.phone.isEmpty ? '-' : patient.phone),
                pw.SizedBox(height: 5),
                _infoPair('PIN', visit.pin),
                pw.SizedBox(height: 5),
                _infoPair('Address',
                    patient.address.isEmpty ? '-' : patient.address),
              ],
            ),
          ),
          pw.Container(
            width: 0.5,
            color: PdfColors.grey300,
            margin: const pw.EdgeInsets.symmetric(horizontal: 10),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoPair('Age', patient.age.isEmpty ? '-' : patient.age),
                pw.SizedBox(height: 5),
                _infoPair('Gender',
                    patient.gender.isEmpty ? '-' : patient.gender),
                pw.SizedBox(height: 5),
                _infoPair('Date', visit.displayDate),
                pw.SizedBox(height: 5),
                _infoPair('Referred',
                    visit.referredBy.isEmpty ? '-' : visit.referredBy),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoPair(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 60,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value.isEmpty ? '-' : value,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSingleSectionTitle(String name) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(
        name,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.Widget _buildSectionHeading(String name) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(
        name,
        style: pw.TextStyle(
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.Widget _buildTestTable(List<LabTest> tests) {
    return pw.Table(
      border: pw.TableBorder.symmetric(
        inside: pw.BorderSide(color: PdfColors.grey300, width: 0.3),
        outside: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(3.5),
        1: pw.FlexColumnWidth(2.0),
        2: pw.FlexColumnWidth(2.0),
        3: pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _headerCell('Test Name'),
            _headerCell('Result'),
            _headerCell('Unit'),
            _headerCell('Reference Range'),
          ],
        ),
        ...tests.map((t) {
          return pw.TableRow(
            children: [
              _dataCell(t.testName, bold: true),
              _dataCell(t.result),
              _dataCell(t.unit),
              _dataCell(t.normalRange),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.Widget _dataCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text.isEmpty ? '-' : text,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }


  // ===========================================================================
  // INVOICE — document builder
  // ===========================================================================

  static pw.Document _buildInvoiceDocument({
    required ClinicInfo clinic,
    required Patient patient,
    required Visit visit,
    required List<LabTest> tests,
  }) {
    final doc = pw.Document();

    final subtotal = tests.fold<double>(0, (s, t) => s + t.price);
    final discount = visit.discount;
    final rawNet = subtotal - discount;
    final netPayable = rawNet < 0 ? 0.0 : rawNet;
    final received = visit.amountReceived;
    final balance = netPayable - received;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 100, 30, 40),
        header: (context) => _buildInvoiceHeader(visit.pin),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 6),
          _buildInvoicePatientBlock(patient: patient, visit: visit),
          pw.SizedBox(height: 14),
          _buildInvoiceTestTable(tests),
          pw.SizedBox(height: 14),
          _buildInvoiceTotals(
            subtotal: subtotal,
            discount: discount,
            netPayable: netPayable,
            received: received,
            balance: balance,
            paymentMode: visit.paymentMode,
          ),
          if (visit.invoiceNotes.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Notes:',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    visit.invoiceNotes,
                    style: const pw.TextStyle(fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 30),
          _buildInvoiceSignatureBlock(clinic.name),
        ],
      ),
    );

    return doc;
  }

  static pw.Widget _buildInvoiceHeader(String refNo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Invoice',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.Text(
              'Ref #$refNo',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1.2, color: PdfColors.blue900),
      ],
    );
  }

  static pw.Widget _buildInvoicePatientBlock({
    required Patient patient,
    required Visit visit,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
        color: PdfColors.grey50,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoPair('Patient', patient.name),
                pw.SizedBox(height: 5),
                _infoPair('Phone',
                    patient.phone.isEmpty ? '-' : patient.phone),
                pw.SizedBox(height: 5),
                _infoPair('PIN', visit.pin),
              ],
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoPair('Date', visit.displayDate),
                pw.SizedBox(height: 5),
                _infoPair('Referred',
                    visit.referredBy.isEmpty ? '-' : visit.referredBy),
                pw.SizedBox(height: 5),
                _infoPair('Invoice', visit.pin),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInvoiceTestTable(List<LabTest> tests) {
    return pw.Table(
      border: pw.TableBorder.symmetric(
        inside: pw.BorderSide(color: PdfColors.grey300, width: 0.3),
        outside: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _headerCell('Test Name'),
            _headerCellRight('Rate (Rs)'),
            _headerCellCenter('Qty'),
            _headerCellRight('Amount (Rs)'),
          ],
        ),
        ...tests.map((t) {
          return pw.TableRow(
            children: [
              _dataCell(t.testName, bold: true),
              _dataCellRight(t.price.toStringAsFixed(0)),
              _dataCellCenter('1'),
              _dataCellRight(t.price.toStringAsFixed(0), bold: true),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildInvoiceTotals({
    required double subtotal,
    required double discount,
    required double netPayable,
    required double received,
    required double balance,
    required String paymentMode,
  }) {
    final balancePositive = balance > 0;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          _totalsRow('Subtotal', subtotal.toStringAsFixed(0)),
          pw.SizedBox(height: 5),
          _totalsRow('Discount', '- ${discount.toStringAsFixed(0)}'),
          pw.SizedBox(height: 5),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.SizedBox(height: 5),
          _totalsRow(
            'Net Payable',
            netPayable.toStringAsFixed(0),
            bold: true,
            larger: true,
          ),
          pw.SizedBox(height: 5),
          _totalsRow('Received ($paymentMode)', received.toStringAsFixed(0)),
          pw.SizedBox(height: 5),
          _totalsRow(
            balancePositive ? 'Balance Due' : 'Balance',
            balance.abs().toStringAsFixed(0),
            bold: true,
            color: balancePositive ? PdfColors.red800 : PdfColors.green800,
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalsRow(
      String label,
      String value, {
        bool bold = false,
        bool larger = false,
        PdfColor? color,
      }) {
    final style = pw.TextStyle(
      fontSize: larger ? 12 : 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color ?? PdfColors.grey900,
    );
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 4,
          child: pw.Text(label, style: style),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            'Rs $value',
            textAlign: pw.TextAlign.right,
            style: style,
          ),
        ),
      ],
    );
  }

  static pw.Widget _headerCellRight(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.Widget _headerCellCenter(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.Widget _dataCellRight(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _dataCellCenter(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 9.5),
      ),
    );
  }

  static pw.Widget _buildInvoiceSignatureBlock(String clinicName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 180, height: 0.6, color: PdfColors.grey700),
            pw.SizedBox(height: 3),
            pw.Text(
              'Received by',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Text(
          clinicName,
          style: pw.TextStyle(
            fontSize: 8,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey500,
          ),
        ),
      ],
    );
  }
}