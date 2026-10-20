import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_service.dart';
import '../theme/app_theme.dart';

const String _appVersion = '1.0.0';
const String _appBuild = 'Phase 3';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _totalPatients = 0;
  int _totalVisits = 0;
  int _totalTests = 0;
  int _totalPanels = 0;
  String _dbPath = '';
  String _dbSize = '—';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _buildDeveloperCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.code_outlined,
              title: 'Developed By',
              subtitle: 'Software built and maintained by',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'AH', // 👈 your initials
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ali Haider', // 👈 your name
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Custom software for labs & clinics',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 👇 optional contact details
                      Row(
                        children: const [
                          Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '0313-5455767',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: const [
                          Icon(
                            Icons.email_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'chalihaidermairvi@gmail.com',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final patients = await DatabaseService.instance.countPatients();
      final visits = await DatabaseService.instance.countVisits();
      final tests = await DatabaseService.instance.countTests();
      final panels = await DatabaseService.instance.getPanels();
      final path = await DatabaseService.instance.getDatabasePath();

      String sizeStr = '—';
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.length();
          sizeStr = _formatBytes(bytes);
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _totalPatients = patients;
        _totalVisits = visits;
        _totalTests = tests;
        _totalPanels = panels.length;
        _dbPath = path;
        _dbSize = sizeStr;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _copyDbPath() async {
    await Clipboard.setData(ClipboardData(text: _dbPath));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database path copied to clipboard.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('About'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAppHeader(),
                      const SizedBox(height: 20),
                      _buildStatsCard(),
                      const SizedBox(height: 16),
                      _buildDataLocationCard(),
                      const SizedBox(height: 16),
                      _buildAboutTextCard(),
                      const SizedBox(height: 16),
                      _buildDeveloperCard(),
                      const SizedBox(height: 16),
                      _buildCopyrightFooter(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildAppHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.biotech_outlined,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Clinic Lab Manager',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version $_appVersion ',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.analytics_outlined,
              title: 'Your Data',
              subtitle: 'Stored locally on this device',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatMini(
                    icon: Icons.people_outline,
                    value: _totalPatients.toString(),
                    label: 'Patients',
                    accent: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatMini(
                    icon: Icons.event_note_outlined,
                    value: _totalVisits.toString(),
                    label: 'Visits',
                    accent: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatMini(
                    icon: Icons.science_outlined,
                    value: _totalTests.toString(),
                    label: 'Tests',
                    accent: const Color(0xFF0EA5E9),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatMini(
                    icon: Icons.dashboard_customize_outlined,
                    value: _totalPanels.toString(),
                    label: 'Panels',
                    accent: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.storage_outlined,
              title: 'Data Location',
              subtitle: 'Where your database is stored on this PC',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 14,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Size: $_dbSize',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _dbPath,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  color: AppColors.text,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _copyDbPath,
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Copy path'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Back this file up regularly. You can also use Settings → '
              'Backup Database to save a dated copy.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTextCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.info_outline,
              title: 'About this app',
              subtitle: 'What it does',
            ),
            const SizedBox(height: 14),
            const Text(
              'Clinic Lab Manager is a local, offline application for managing '
              'diagnostic lab operations. It helps you:',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.text,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const _Bullet(text: 'Register patients and their visits'),
            const _Bullet(text: 'Add multiple tests per visit using panels'),
            const _Bullet(
              text: 'Generate multi-test reports and invoices as PDFs',
            ),
            const _Bullet(text: 'Track payments and print receipts'),
            const _Bullet(text: 'Back up and restore all data safely'),
            const SizedBox(height: 16),
            const Text(
              'All data is stored locally on this device — no internet '
              'connection is required, and no data leaves your PC.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyrightFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        children: [
          // Replace these with YOUR details
          const Text(
            'Developed by Ali Haider',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'For ALI AMJAD DIAGNOSTIC CENTER',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          const Text(
            '© 2026 · All rights reserved',
            style: TextStyle(fontSize: 11, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }

  String _shortClinicName() {
    // Best-effort clinic name for the footer. If empty, fall back.
    return 'ALI AMJAD DIAGNOSTIC CENTER';
  }
}

// -----------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  const _StatMini({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7, right: 10),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
