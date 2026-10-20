import 'package:flutter/material.dart';

import '../db/database_service.dart';
import '../models/lab_test.dart';
import '../models/patient.dart';
import '../models/visit.dart';
import '../theme/app_theme.dart';
import 'add_visit_screen.dart';
import 'visit_detail_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  List<Visit> _allVisits = [];
  List<Visit> _filteredVisits = [];
  final Map<int, int> _testCounts = {};
  // Paid state per visit (from invoice)
  final Map<int, bool> _paidState = {};
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
        _applyFilter();
      });
    });
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final visits =
    await DatabaseService.instance.getVisitsForPatient(widget.patient.id!);

    final counts = <int, int>{};
    final paid = <int, bool>{};
    for (final v in visits) {
      counts[v.id!] =
      await DatabaseService.instance.countTestsForVisit(v.id!);
      paid[v.id!] = await DatabaseService.instance.isVisitPaid(v.id!);
    }

    if (mounted) {
      setState(() {
        _allVisits = visits;
        _testCounts
          ..clear()
          ..addAll(counts);
        _paidState
          ..clear()
          ..addAll(paid);
        _applyFilter();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredVisits = List.from(_allVisits);
    } else {
      _filteredVisits = _allVisits.where((v) {
        return v.pin.toLowerCase().contains(_searchQuery) ||
            v.referredBy.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _addVisit() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddVisitScreen(patient: widget.patient),
      ),
    );
    if (added == true) {
      await _load();
    }
  }

  Future<void> _openVisit(Visit visit) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitDetailScreen(
          visit: visit,
          patient: widget.patient,
        ),
      ),
    );
    // Always reload — the paid state may have changed after invoice edits.
    await _load();
  }

  Future<void> _deleteVisit(Visit visit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete visit?'),
        content: Text(
          'Delete visit ${visit.pin} and all its tests? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await DatabaseService.instance.deleteVisit(visit.id!);
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  String get _lastVisitDate {
    if (_allVisits.isEmpty) return '—';
    return _allVisits.first.displayDate;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Patient Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit patient',
            onPressed: () => Navigator.pop(context, 'edit'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPatientHeader(p),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 20),
              _buildVisitsSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildPatientHeader(Patient p) {
    final initial = p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (p.age.isNotEmpty)
                            _InfoChip(
                                icon: Icons.cake_outlined,
                                text: 'Age ${p.age}'),
                          if (p.gender.isNotEmpty)
                            _InfoChip(
                                icon: Icons.wc_outlined, text: p.gender),
                          if (p.phone.isNotEmpty)
                            _InfoChip(
                                icon: Icons.phone_outlined, text: p.phone),
                        ],
                      ),
                      if (p.address.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.home_outlined,
                                size: 14, color: AppColors.textFaint),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p.address,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Added ${p.dateAdded.length >= 10 ? p.dateAdded.substring(0, 10) : p.dateAdded}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textFaint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addVisit,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Visit for this Patient'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.event_note_outlined,
            label: 'Total Visits',
            value: _allVisits.length.toString(),
            accent: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.schedule,
            label: 'Last Visit',
            value: _lastVisitDate,
            accent: const Color(0xFF0EA5E9),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitsSection() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_allVisits.isEmpty) {
      return _emptyAllVisits();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search visits by PIN or referred-by…',
            prefixIcon: const Icon(Icons.search),
            fillColor: AppColors.surface,
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => _searchCtrl.clear(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            _searchQuery.isEmpty
                ? '${_allVisits.length} visit${_allVisits.length == 1 ? "" : "s"}'
                : '${_filteredVisits.length} of ${_allVisits.length} visit${_allVisits.length == 1 ? "" : "s"}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        if (_filteredVisits.isEmpty)
          _noMatchState()
        else
          ..._filteredVisits.map(_buildVisitRow),
      ],
    );
  }

  Widget _emptyAllVisits() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_note_outlined,
                size: 32, color: AppColors.textFaint),
          ),
          const SizedBox(height: 14),
          const Text(
            'No visits yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap "Add Visit for this Patient" to record their first visit.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _noMatchState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_outlined,
              size: 28, color: AppColors.textFaint),
          const SizedBox(height: 10),
          const Text(
            'No matching visits',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No visit matches "$_searchQuery"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitRow(Visit v) {
    final count = _testCounts[v.id] ?? 0;
    final paid = _paidState[v.id] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openVisit(v),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event_note_outlined,
                      color: AppColors.primaryDark, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'PIN ${v.pin}',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _PaidBadge(paid: paid),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${v.displayDate} · ${v.referredBy}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count test${count == 1 ? "" : "s"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textFaint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete visit',
                  color: AppColors.error,
                  onPressed: () => _deleteVisit(v),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textFaint, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Status badge — driven by payment, not tests
// -----------------------------------------------------------------------------

class _PaidBadge extends StatelessWidget {
  final bool paid;
  const _PaidBadge({required this.paid});

  @override
  Widget build(BuildContext context) {
    final bg =
    paid ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7);
    final fg =
    paid ? const Color(0xFF065F46) : const Color(0xFF92400E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paid ? Icons.check_circle_outline : Icons.schedule,
            size: 11,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            paid ? 'PAID' : 'PENDING',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Small widgets
// -----------------------------------------------------------------------------

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
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