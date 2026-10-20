import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../tabs/dashboard_tab.dart';
import '../tabs/patients_tab.dart';
import '../tabs/view_reports_tab.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  /// Bumping this key fully rebuilds every tab (and re-runs their initState).
  /// Effectively a "soft reload" of the app's content.
  int _reloadKey = 0;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToTab(int index) => _controller.animateTo(index);

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _reloadApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reload app?'),
        content: const Text(
          'This will refresh all tabs with the latest data. '
              'Any unsaved changes in an open form will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reload'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _reloadKey++;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('App reloaded.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20, top: 12, bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.biotech_outlined,
                color: Colors.white, size: 22),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'ALI AMJAD DIAGNOSTIC CENTER',
              style: TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                letterSpacing: -0.2,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Jand Branch',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                    letterSpacing: 0.1,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // "Local" pill
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
              message: 'Data is stored locally on this device',
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storage_outlined,
                        size: 14, color: AppColors.primaryDark),
                    SizedBox(width: 6),
                    Text(
                      'Local',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Reload icon
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            tooltip: 'Reload app (refresh all data)',
            onPressed: _reloadApp,
          ),
          // Settings icon
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.tune, size: 22),
              tooltip: 'Settings',
              onPressed: _openSettings,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(text: 'Home', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: 'Patients', icon: Icon(Icons.people_outline)),
            Tab(text: 'Reports', icon: Icon(Icons.receipt_long_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        // The key forces a full rebuild of all tabs when bumped.
        key: ValueKey(_reloadKey),
        controller: _controller,
        children: [
          DashboardTab(
            onGoToPatients: () => _goToTab(1),
            onGoToAddReport: () => _goToTab(1),
            onGoToReports: () => _goToTab(2),
          ),
          const PatientsTab(),
          const ViewReportsTab(),
        ],
      ),
    );
  }
}