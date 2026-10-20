import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../db/database_service.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'clinic_info_screen.dart';
import 'panels_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  // ---------------------------------------------------------------------------
  // Backup
  // ---------------------------------------------------------------------------

  Future<void> _backupDatabase() async {
    final now = DateTime.now();
    final defaultName =
        'cliniclab_${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}.db';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup as',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      if (savePath == null) return; // user cancelled

      setState(() => _busy = true);

      // On some platforms saveFile may return a path without the .db suffix.
      final finalPath = savePath.toLowerCase().endsWith('.db')
          ? savePath
          : '$savePath.db';

      await DatabaseService.instance.backupDatabase(finalPath);

      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('Backup saved to:\n$finalPath'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  // ---------------------------------------------------------------------------
  // Restore
  // ---------------------------------------------------------------------------

  Future<void> _restoreDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'This will REPLACE ALL current patients, visits, invoices, and '
          'panels with the data from the backup file.\n\n'
          'This cannot be undone.\n\n'
          'The app will close after restoring. You can reopen it to see the '
          'restored data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Pick a backup file',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;

      setState(() => _busy = true);

      await DatabaseService.instance.restoreDatabase(path);

      if (!mounted) return;
      setState(() => _busy = false);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore complete'),
          content: const Text(
            'Your data has been restored.\n\n'
            'Please close and reopen the app to see the restored data.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildIntro(),
              const SizedBox(height: 20),

              _buildSectionLabel('Manage'),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.dashboard_customize_outlined,
                title: 'Test Panels',
                subtitle: 'Create reusable panels like CBC, LFT, Lipid Profile',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PanelsScreen()),
                ),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.local_hospital_outlined,
                title: 'Clinic Info',
                subtitle: 'Name, address, phone shown on reports & invoices',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClinicInfoScreen()),
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionLabel('Data'),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.save_alt_outlined,
                title: 'Backup Database',
                subtitle: 'Save a dated copy of all your data to a folder',
                onTap: _busy ? null : _backupDatabase,
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.restore_outlined,
                title: 'Restore from Backup',
                subtitle: 'Load data from a backup file (replaces current)',
                danger: true,
                onTap: _busy ? null : _restoreDatabase,
              ),

              const SizedBox(height: 24),
              _buildSectionLabel('About'),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'About this app',
                subtitle: 'Version, developer, license',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black.withValues(alpha: 0.15),
              alignment: Alignment.center,
              child: const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 14),
                      Text(
                        'Working…',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: AppColors.primaryDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Settings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage your test panels, clinic information, and keep your '
                  'data safe with backups.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.text,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final accent = danger ? AppColors.error : AppColors.primaryDark;
    final iconBg = danger
        ? AppColors.error.withValues(alpha: 0.12)
        : AppColors.primaryLight;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: danger
                  ? AppColors.error.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: disabled ? AppColors.textMuted : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: disabled ? AppColors.textFaint : AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
