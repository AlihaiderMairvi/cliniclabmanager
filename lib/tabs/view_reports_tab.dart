import 'package:flutter/material.dart';

import '../db/database_service.dart';
import '../models/patient.dart';
import '../models/visit.dart';
import '../screens/visit_detail_screen.dart';
import '../theme/app_theme.dart';

class ViewReportsTab extends StatefulWidget {
  const ViewReportsTab({super.key});

  @override
  State<ViewReportsTab> createState() => _ViewReportsTabState();
}

class _ViewReportsTabState extends State<ViewReportsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Patient> _patients = [];
  List<Visit> _allVisits = [];
  List<Visit> _filteredVisits = [];
  // Map<visitId, patientName> for display
  final Map<int, String> _patientNames = {};
  // Map<visitId, testCount> for the badge
  final Map<int, int> _testCounts = {};
  Patient? _filterPatient;
  bool _isLoading = true;

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
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final patients = await DatabaseService.instance.getPatients();

      // Keep the filter pointing to a fresh Patient instance by id.
      Patient? resolvedFilter;
      if (_filterPatient != null) {
        for (final p in patients) {
          if (p.id == _filterPatient!.id) {
            resolvedFilter = p;
            break;
          }
        }
      }

      final visits = await DatabaseService.instance.getVisits(
        patientId: resolvedFilter?.id,
      );

      // Preload names + counts
      final namesById = <int, String>{};
      for (final p in patients) {
        namesById[p.id!] = p.name;
      }
      final counts = <int, int>{};
      for (final v in visits) {
        counts[v.id!] =
        await DatabaseService.instance.countTestsForVisit(v.id!);
      }

      if (!mounted) return;
      setState(() {
        _patients = patients;
        _filterPatient = resolvedFilter;
        _allVisits = visits;
        _patientNames
          ..clear()
          ..addAll({for (final v in visits) v.id!: namesById[v.patientId] ?? 'Unknown'});
        _testCounts
          ..clear()
          ..addAll(counts);
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredVisits = List.from(_allVisits);
      return;
    }
    _filteredVisits = _allVisits.where((v) {
      final patientName = (_patientNames[v.id] ?? '').toLowerCase();
      return v.pin.toLowerCase().contains(_searchQuery) ||
          patientName.contains(_searchQuery) ||
          v.referredBy.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _openVisit(Visit visit) async {
    final patient = _patients.firstWhere(
          (p) => p.id == visit.patientId,
      orElse: () => _patients.isNotEmpty
          ? _patients.first
          : throw StateError('No patients'),
    );
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VisitDetailScreen(
          visit: visit,
          patient: patient,
        ),
      ),
    );
    if (changed == true) await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterBar(),
          const SizedBox(height: 12),
          _buildSearchField(),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, right: 8),
              child: Icon(Icons.filter_list,
                  size: 18, color: AppColors.textMuted),
            ),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Patient?>(
                  value: _filterPatient,
                  isExpanded: true,
                  isDense: true,
                  icon: const Icon(Icons.expand_more, size: 20),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                  items: [
                    const DropdownMenuItem<Patient?>(
                      value: null,
                      child: Text('All patients'),
                    ),
                    ..._patients.map(
                          (p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          p.displayLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (p) {
                    setState(() => _filterPatient = p);
                    _loadAll();
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh',
              onPressed: _loadAll,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Search by PIN, patient name, or referred-by…',
        prefixIcon: const Icon(Icons.search),
        fillColor: AppColors.surface,
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => _searchCtrl.clear(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_allVisits.isEmpty) {
      return _emptyState(
        title: _filterPatient == null
            ? 'No visits yet'
            : 'No visits for this patient',
        subtitle: _filterPatient == null
            ? 'Add a visit from a patient\'s detail screen.'
            : 'Try selecting a different patient.',
      );
    }
    if (_filteredVisits.isEmpty) {
      return _noMatchState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        Expanded(
          child: ListView.separated(
            itemCount: _filteredVisits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _VisitCard(
              visit: _filteredVisits[i],
              patientName:
              _patientNames[_filteredVisits[i].id] ?? 'Unknown patient',
              testCount: _testCounts[_filteredVisits[i].id] ?? 0,
              onTap: () => _openVisit(_filteredVisits[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState({required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_note_outlined,
                size: 36, color: AppColors.textFaint),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _noMatchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_outlined,
                size: 32, color: AppColors.textFaint),
          ),
          const SizedBox(height: 14),
          const Text(
            'No matching visits',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No visit matches "$_searchQuery"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final Visit visit;
  final String patientName;
  final int testCount;
  final VoidCallback onTap;

  const _VisitCard({
    required this.visit,
    required this.patientName,
    required this.testCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
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
                    Text(
                      'PIN ${visit.pin}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Tag(
                          icon: Icons.schedule,
                          label: visit.displayDate,
                        ),
                        _Tag(
                          icon: Icons.science_outlined,
                          label:
                          '$testCount test${testCount == 1 ? "" : "s"}',
                        ),
                        if (visit.referredBy.isNotEmpty)
                          _Tag(
                            icon: Icons.local_hospital_outlined,
                            label: visit.referredBy,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textFaint, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Tag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}