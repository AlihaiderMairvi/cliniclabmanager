import 'package:flutter/material.dart';
import '../db/database_service.dart';
import '../models/lab_test.dart';
import '../models/patient.dart';
import '../models/visit.dart';
import '../theme/app_theme.dart';
import 'report_preview_screen.dart';
import 'invoice_screen.dart';

class VisitDetailScreen extends StatefulWidget {
  final Visit visit;
  final Patient patient;

  const VisitDetailScreen({
    super.key,
    required this.visit,
    required this.patient,
  });

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  List<LabTest> _tests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tests = await DatabaseService.instance.getTestsForVisit(
      widget.visit.id!,
    );
    if (mounted) {
      setState(() {
        _tests = tests;
        _loading = false;
      });
    }
  }

  Map<String, List<LabTest>> get _grouped {
    final Map<String, List<LabTest>> map = {};
    for (final t in _tests) {
      final key = t.section.isEmpty ? 'General' : t.section;
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  // ---- Preview screens ----
  Future<void> _previewSingleTest(LabTest test) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPreviewScreen(
          patient: widget.patient,
          visit: widget.visit,
          tests: [test],
        ),
      ),
    );
  }

  Future<void> _previewFullReport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPreviewScreen(
          patient: widget.patient,
          visit: widget.visit,
          tests: _tests,
        ),
      ),
    );
  }

  // ---- Open Invoice screen ----
  Future<void> _openInvoice() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            InvoiceScreen(visit: widget.visit, patient: widget.patient),
      ),
    );
    // Always reload after returning — the invoice may have changed the visit's
    // paid state, and we want the tests view to stay in sync.
    await _load();
  }

  Future<void> _editTest(LabTest test) async {
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _EditTestDialog(test: test),
    );
    if (result == null) return;

    try {
      await DatabaseService.instance.updateTest(result.updated);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  Future<void> _deleteTest(LabTest test) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete test?'),
        content: Text('Delete "${test.testName}" from this visit?'),
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
        await DatabaseService.instance.deleteTest(test.id!);
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Visit Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
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
              _buildVisitHeader(),
              const SizedBox(height: 16),
              _buildActionRow(),
              const SizedBox(height: 20),
              _buildTestsSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildVisitHeader() {
    final v = widget.visit;
    final p = widget.patient;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PIN ${v.pin}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Patient',
              value: p.name,
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.event_outlined,
              label: 'Date',
              value: v.displayDate,
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.local_hospital_outlined,
              label: 'Referred by',
              value: v.referredBy,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _tests.isEmpty ? null : _previewFullReport,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('View Full Report'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _tests.isEmpty ? null : _openInvoice,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Invoice'),
          ),
        ),
      ],
    );
  }

  Widget _buildTestsSection() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_tests.isEmpty) {
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
              child: const Icon(
                Icons.science_outlined,
                size: 32,
                color: AppColors.textFaint,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No tests in this visit',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      );
    }

    final grouped = _grouped;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_tests.length} test${_tests.length == 1 ? "" : "s"}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        for (final section in grouped.keys) ...[
          _buildSectionHeader(section),
          const SizedBox(height: 8),
          ...grouped[section]!.map(_buildTestRow),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.category_outlined,
            size: 16,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestRow(LabTest t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.testName,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (t.result.isNotEmpty)
                    _MiniTag(label: 'Result: ${t.result}'),
                  if (t.unit.isNotEmpty) _MiniTag(label: 'Unit: ${t.unit}'),
                  if (t.normalRange.isNotEmpty)
                    _MiniTag(label: 'Range: ${t.normalRange}'),
                  if (t.price > 0)
                    _MiniTag(
                      label: 'Rs ${t.price.toStringAsFixed(0)}',
                      highlight: true,
                    ),
                ],
              ),
              if (t.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t.notes,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.text,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.primary,
                    tooltip: 'Edit',
                    onPressed: () => _editTest(t),
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    color: AppColors.primary,
                    tooltip: 'Preview / print this test',
                    onPressed: () => _previewSingleTest(t),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.error,
                    tooltip: 'Delete test',
                    onPressed: () => _deleteTest(t),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Edit dialog — status field removed (payment drives status now)
// -----------------------------------------------------------------------------

class _EditResult {
  final LabTest updated;

  _EditResult(this.updated);
}

class _EditTestDialog extends StatefulWidget {
  final LabTest test;

  const _EditTestDialog({required this.test});

  @override
  State<_EditTestDialog> createState() => _EditTestDialogState();
}

class _EditTestDialogState extends State<_EditTestDialog> {
  late final TextEditingController _resultCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _rangeCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _resultCtrl = TextEditingController(text: widget.test.result);
    _unitCtrl = TextEditingController(text: widget.test.unit);
    _rangeCtrl = TextEditingController(text: widget.test.normalRange);
    _notesCtrl = TextEditingController(text: widget.test.notes);
    _priceCtrl = TextEditingController(
      text: widget.test.price > 0 ? widget.test.price.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _resultCtrl.dispose();
    _unitCtrl.dispose();
    _rangeCtrl.dispose();
    _notesCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final updated = widget.test.copyWith(
      result: _resultCtrl.text.trim(),
      unit: _unitCtrl.text.trim(),
      normalRange: _rangeCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      price: price,
      // No status change here — the status field is no longer surfaced in the UI.
    );
    Navigator.pop(context, _EditResult(updated));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.test.testName),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _resultCtrl,
                decoration: const InputDecoration(
                  labelText: 'Result',
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  prefixIcon: Icon(Icons.straighten_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rangeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Normal range',
                  prefixIcon: Icon(Icons.rule_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price (Rs)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Small widgets
// -----------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final bool highlight;

  const _MiniTag({required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primaryLight : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          color: highlight ? AppColors.primaryDark : AppColors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}