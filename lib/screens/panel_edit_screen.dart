import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_service.dart';
import '../models/panel.dart';
import '../models/panel_test.dart';
import '../theme/app_theme.dart';

class PanelEditScreen extends StatefulWidget {
  final int panelId;

  const PanelEditScreen({super.key, required this.panelId});

  @override
  State<PanelEditScreen> createState() => _PanelEditScreenState();
}

class _PanelEditScreenState extends State<PanelEditScreen> {
  Panel? _panel;
  List<PanelTest> _tests = [];
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final panel = await DatabaseService.instance.getPanel(widget.panelId);
    final tests = await DatabaseService.instance.getPanelTests(widget.panelId);
    if (mounted) {
      setState(() {
        _panel = panel;
        _tests = tests;
        _loading = false;
      });
    }
  }

  double get _totalPrice =>
      _tests.fold(0.0, (sum, t) => sum + t.price);

  // ---------------------------------------------------------------------------
  // Rename panel
  // ---------------------------------------------------------------------------

  Future<void> _renamePanel() async {
    if (_panel == null) return;
    final ctrl = TextEditingController(text: _panel!.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename panel'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Panel name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == _panel!.name) return;

    try {
      await DatabaseService.instance
          .updatePanel(_panel!.copyWith(name: newName));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Add / edit / delete a test
  // ---------------------------------------------------------------------------

  Future<void> _addTest() async {
    final result = await showDialog<PanelTest>(
      context: context,
      builder: (_) => _TestEditDialog(
        panelId: widget.panelId,
        displayOrder: _tests.length,
      ),
    );
    if (result == null) return;

    try {
      await DatabaseService.instance.insertPanelTest(result);
      _dirty = true;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add test: $e')),
        );
      }
    }
  }

  Future<void> _editTest(PanelTest test) async {
    final result = await showDialog<PanelTest>(
      context: context,
      builder: (_) => _TestEditDialog(
        panelId: widget.panelId,
        existing: test,
      ),
    );
    if (result == null) return;

    try {
      await DatabaseService.instance.updatePanelTest(result);
      _dirty = true;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _deleteTest(PanelTest test) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete test?'),
        content: Text('Remove "${test.testName}" from this panel?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await DatabaseService.instance.deletePanelTest(test.id!);
        _dirty = true;
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

  // ---------------------------------------------------------------------------
  // Bulk add (parser now handles an optional 4th price column)
  // ---------------------------------------------------------------------------

  Future<void> _bulkAdd() async {
    final result = await showDialog<List<PanelTest>>(
      context: context,
      builder: (_) => _BulkAddDialog(panelId: widget.panelId),
    );
    if (result == null || result.isEmpty) return;

    try {
      var order = _tests.length;
      for (final t in result) {
        await DatabaseService.instance.insertPanelTest(
          t.copyWith(displayOrder: order++),
        );
      }
      _dirty = true;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${result.length} tests.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Reorder
  // ---------------------------------------------------------------------------

  Future<void> _moveTest(int index, int delta) async {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _tests.length) return;
    setState(() {
      final item = _tests.removeAt(index);
      _tests.insert(newIndex, item);
    });
    try {
      for (int i = 0; i < _tests.length; i++) {
        await DatabaseService.instance
            .updatePanelTest(_tests[i].copyWith(displayOrder: i));
      }
      _dirty = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reorder: $e')),
        );
      }
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
        title: Text(_panel?.name ?? 'Panel'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _dirty),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_file_rename_outline, size: 20),
            tooltip: 'Rename panel',
            onPressed: _loading ? null : _renamePanel,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(child: _buildBody()),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_tests.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildIntro(),
            const SizedBox(height: 16),
            _emptyState(),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildIntro(),
        const SizedBox(height: 16),
        _buildSummaryBar(),
        const SizedBox(height: 12),
        for (int i = 0; i < _tests.length; i++) _buildTestRow(i),
      ],
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.primaryDark, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add tests with their unit, reference range, and price. When this '
                  'panel is used in a visit, these fields fill in automatically.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            '${_tests.length} test${_tests.length == 1 ? "" : "s"}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          const Text(
            'Total:',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Rs ${_totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
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
            child: const Icon(Icons.science_outlined,
                size: 32, color: AppColors.textFaint),
          ),
          const SizedBox(height: 14),
          const Text(
            'No tests in this panel',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap "Add Test" below, or "Bulk Add" to paste from a spreadsheet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildTestRow(int index) {
    final t = _tests[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _editTest(t),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Up/down reorder
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: index == 0 ? null : () => _moveTest(index, -1),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.keyboard_arrow_up,
                            size: 18,
                            color: index == 0
                                ? AppColors.textFaint
                                : AppColors.text),
                      ),
                    ),
                    InkWell(
                      onTap: index == _tests.length - 1
                          ? null
                          : () => _moveTest(index, 1),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.keyboard_arrow_down,
                            size: 18,
                            color: index == _tests.length - 1
                                ? AppColors.textFaint
                                : AppColors.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (t.section.isNotEmpty) ...[
                        Text(
                          t.section,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        t.testName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (t.unit.isNotEmpty)
                            _MiniTag(label: 'Unit: ${t.unit}'),
                          if (t.normalRange.isNotEmpty)
                            _MiniTag(label: 'Range: ${t.normalRange}'),
                          if (t.price > 0)
                            _MiniTag(
                              label: 'Rs ${t.price.toStringAsFixed(0)}',
                              highlight: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.primary,
                  tooltip: 'Edit',
                  onPressed: () => _editTest(t),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.error,
                  tooltip: 'Delete',
                  onPressed: () => _deleteTest(t),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _bulkAdd,
              icon: const Icon(Icons.content_paste, size: 18),
              label: const Text('Bulk Add'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _addTest,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Test'),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Single-test edit dialog (now includes Price)
// -----------------------------------------------------------------------------

class _TestEditDialog extends StatefulWidget {
  final int panelId;
  final PanelTest? existing;
  final int displayOrder;

  const _TestEditDialog({
    required this.panelId,
    this.existing,
    this.displayOrder = 0,
  });

  @override
  State<_TestEditDialog> createState() => _TestEditDialogState();
}

class _TestEditDialogState extends State<_TestEditDialog> {
  late final TextEditingController _sectionCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _rangeCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _sectionCtrl = TextEditingController(text: t?.section ?? '');
    _nameCtrl = TextEditingController(text: t?.testName ?? '');
    _unitCtrl = TextEditingController(text: t?.unit ?? '');
    _rangeCtrl = TextEditingController(text: t?.normalRange ?? '');
    _priceCtrl = TextEditingController(
      text: (t?.price ?? 0) > 0 ? (t!.price.toStringAsFixed(0)) : '',
    );
  }

  @override
  void dispose() {
    _sectionCtrl.dispose();
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _rangeCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test name is required.')),
      );
      return;
    }
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final result = (widget.existing ?? PanelTest(
      panelId: widget.panelId,
      testName: '',
    )).copyWith(
      section: _sectionCtrl.text.trim(),
      testName: name,
      unit: _unitCtrl.text.trim(),
      normalRange: _rangeCtrl.text.trim(),
      displayOrder: widget.existing?.displayOrder ?? widget.displayOrder,
      price: price,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Test' : 'Add Test'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _sectionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Section (optional)',
                  hintText: 'e.g. CBC, Diff.Leuc.Count (DLC)',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Test name *',
                  hintText: 'e.g. WBC',
                  prefixIcon: Icon(Icons.science_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  hintText: 'e.g. x 10^9/L',
                  prefixIcon: Icon(Icons.straighten_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rangeCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reference range',
                  hintText: 'e.g. (M: 4.0-10.0) (F: 4.0-10.0)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.rule_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: false),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Price (Rs)',
                  hintText: 'e.g. 500',
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
        ElevatedButton(
          onPressed: _save,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Bulk add dialog (now parses an optional 4th column for price)
// -----------------------------------------------------------------------------

class _BulkAddDialog extends StatefulWidget {
  final int panelId;
  const _BulkAddDialog({required this.panelId});

  @override
  State<_BulkAddDialog> createState() => _BulkAddDialogState();
}

class _BulkAddDialogState extends State<_BulkAddDialog> {
  final _textCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _defaultPriceCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _textCtrl.dispose();
    _sectionCtrl.dispose();
    _defaultPriceCtrl.dispose();
    super.dispose();
  }

  void _parse() {
    final raw = _textCtrl.text;
    final section = _sectionCtrl.text.trim();
    final defaultPrice = double.tryParse(_defaultPriceCtrl.text.trim()) ?? 0;
    final lines = raw.split('\n');
    final List<PanelTest> result = [];
    var order = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Format: Test | Unit | Range | Price (price optional)
      final parts = trimmed
          .split(RegExp(r'\t|\s*\|\s*'))
          .map((p) => p.trim())
          .toList();

      if (parts.isEmpty || parts[0].isEmpty) continue;

      final testName = parts[0];
      final unit = parts.length > 1 ? parts[1] : '';
      final range = parts.length > 2 ? parts[2] : '';
      final price = parts.length > 3
          ? (double.tryParse(parts[3]) ?? defaultPrice)
          : defaultPrice;

      result.add(PanelTest(
        panelId: widget.panelId,
        section: section,
        testName: testName,
        unit: unit,
        normalRange: range,
        displayOrder: order++,
        price: price,
      ));
    }

    if (result.isEmpty) {
      setState(() => _error = 'No valid rows found.');
      return;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bulk Add Tests'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'One test per line. Format:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Test name | Unit | Reference range | Price (optional)\n'
                      'WBC | x 10^9/L | (M: 4.0-10.0) (F: 4.0-10.0) | 500\n'
                      'RBC | x 10^12/L | (M: 4.5-6.3) (F: 3.50-5.50)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sectionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Section for all these tests (optional)',
                  hintText: 'e.g. CBC',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _defaultPriceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: false),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Default price (Rs) — used when line has no price',
                  hintText: 'e.g. 500',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textCtrl,
                maxLines: 10,
                minLines: 6,
                decoration: InputDecoration(
                  labelText: 'Paste tests here',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  errorText: _error,
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
        ElevatedButton(
          onPressed: _parse,
          child: const Text('Add Tests'),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------

class _MiniTag extends StatelessWidget {
  final String label;
  final bool highlight;
  const _MiniTag({required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primaryLight : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: highlight ? AppColors.primaryDark : AppColors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}