import 'package:flutter/material.dart';

import '../db/database_service.dart';
import '../models/patient.dart';
import '../models/visit.dart';
import '../theme/app_theme.dart';

class DashboardTab extends StatefulWidget {
  final VoidCallback? onGoToPatients;
  final VoidCallback? onGoToAddReport;
  final VoidCallback? onGoToReports;

  const DashboardTab({
    super.key,
    this.onGoToPatients,
    this.onGoToAddReport,
    this.onGoToReports,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _totalPatients = 0;
  int _totalVisits = 0;
  int _todayVisits = 0;
  int _weekVisits = 0;
  List<Visit> _recentVisits = [];
  List<Patient> _recentPatients = [];
  final Map<int, String> _patientNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(const Duration(days: 6));

      final results = await Future.wait([
        DatabaseService.instance.countPatients(),
        DatabaseService.instance.countVisits(),
        DatabaseService.instance.countVisitsSince(todayStart),
        DatabaseService.instance.countVisitsSince(weekStart),
        DatabaseService.instance.getRecentVisits(limit: 5),
        DatabaseService.instance.getRecentPatients(limit: 5),
      ]);

      final recentVisits = results[4] as List<Visit>;

      // Preload patient names for the recent visits
      final allPatients = await DatabaseService.instance.getPatients();
      final nameMap = <int, String>{
        for (final p in allPatients) p.id!: p.name,
      };

      if (!mounted) return;
      setState(() {
        _totalPatients = results[0] as int;
        _totalVisits = results[1] as int;
        _todayVisits = results[2] as int;
        _weekVisits = results[3] as int;
        _recentVisits = recentVisits;
        _recentPatients = results[5] as List<Patient>;
        _patientNames
          ..clear()
          ..addAll({
            for (final v in recentVisits)
              v.id!: nameMap[v.patientId] ?? 'Unknown patient',
          });
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard: $e')),
        );
      }
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$_greeting 👋',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Here's what's happening at your clinic",
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            // -------- Quick actions --------
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'New Patient',
                    onTap: widget.onGoToPatients,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.note_add_outlined,
                    label: 'New Visit',
                    onTap: widget.onGoToPatients, // opens Patients tab to pick
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // -------- KPI cards --------
            LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth > 640;
              final cards = [
                _StatCard(
                  icon: Icons.people_outline,
                  label: 'Total Patients',
                  value: _totalPatients.toString(),
                  accent: AppColors.primary,
                ),
                _StatCard(
                  icon: Icons.event_note_outlined,
                  label: 'Total Visits',
                  value: _totalVisits.toString(),
                  accent: const Color(0xFF7C3AED),
                ),
                _StatCard(
                  icon: Icons.today_outlined,
                  label: "Today's Visits",
                  value: _todayVisits.toString(),
                  accent: const Color(0xFF0EA5E9),
                ),
                _StatCard(
                  icon: Icons.date_range_outlined,
                  label: 'This Week',
                  value: _weekVisits.toString(),
                  accent: const Color(0xFFD97706),
                ),
              ];

              if (wide) {
                return Row(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  Row(children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[3]),
                  ]),
                ],
              );
            }),
            const SizedBox(height: 24),

            // -------- Recent visits --------
            _SectionTitle(
              title: 'Recent Visits',
              actionLabel: 'View all',
              onAction: widget.onGoToReports,
            ),
            const SizedBox(height: 10),
            if (_recentVisits.isEmpty)
              const _EmptyCard(
                icon: Icons.event_note_outlined,
                text: 'No visits yet',
              )
            else
              ..._recentVisits.map((v) => _RecentVisitRow(
                visit: v,
                patientName: _patientNames[v.id] ?? 'Unknown patient',
              )),
            const SizedBox(height: 24),

            // -------- Recent patients --------
            _SectionTitle(
              title: 'Recent Patients',
              actionLabel: 'View all',
              onAction: widget.onGoToPatients,
            ),
            const SizedBox(height: 10),
            if (_recentPatients.isEmpty)
              const _EmptyCard(
                icon: Icons.people_outline,
                text: 'No patients yet',
              )
            else
              ..._recentPatients.map((p) => _RecentPatientRow(patient: p)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sub-widgets
// -----------------------------------------------------------------------------

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  const _SectionTitle({
    required this.title,
    required this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel,
                    style: const TextStyle(fontSize: 12.5)),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward, size: 14),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentVisitRow extends StatelessWidget {
  final Visit visit;
  final String patientName;
  const _RecentVisitRow({required this.visit, required this.patientName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_note_outlined,
                  size: 18, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PIN ${visit.pin}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              visit.displayDate,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textFaint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPatientRow extends StatelessWidget {
  final Patient patient;
  const _RecentPatientRow({required this.patient});

  @override
  Widget build(BuildContext context) {
    final initial =
    patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (patient.age.isNotEmpty) 'Age ${patient.age}',
                      if (patient.gender.isNotEmpty) patient.gender,
                      if (patient.phone.isNotEmpty) patient.phone,
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              patient.dateAdded.length >= 10
                  ? patient.dateAdded.substring(0, 10)
                  : patient.dateAdded,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textFaint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.textFaint),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}