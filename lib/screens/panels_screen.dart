import 'package:flutter/material.dart';

import '../db/database_service.dart';
import '../models/panel.dart';
import '../theme/app_theme.dart';
import 'panel_edit_screen.dart';

class PanelsScreen extends StatefulWidget {
  const PanelsScreen({super.key});

  @override
  State<PanelsScreen> createState() => _PanelsScreenState();
}

class _PanelsScreenState extends State<PanelsScreen> {
  List<Panel> _panels = [];
  final Map<int, int> _testCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final panels = await DatabaseService.instance.getPanels();

    final counts = <int, int>{};
    for (final p in panels) {
      counts[p.id!] = await DatabaseService.instance.countTestsInPanel(p.id!);
    }

    if (mounted) {
      setState(() {
        _panels = panels;
        _testCounts
          ..clear()
          ..addAll(counts);
        _loading = false;
      });
    }
  }

  Future<void> _createNewPanel() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewPanelDialog(),
    );
    if (name == null || name.trim().isEmpty) return;

    try {
      final id = await DatabaseService.instance.insertPanel(
        Panel(
          name: name.trim(),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      if (!mounted) return;

      // Open the new panel in edit mode immediately
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PanelEditScreen(panelId: id),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create panel: $e')),
        );
      }
    }
  }

  Future<void> _openPanel(Panel panel) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PanelEditScreen(panelId: panel.id!),
      ),
    );
    await _load();
  }

  Future<void> _deletePanel(Panel panel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete panel?'),
        content: Text(
          'Delete "${panel.name}" and all its tests?\n\n'
              'Existing visits that already used this panel are not affected.',
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
        await DatabaseService.instance.deletePanel(panel.id!);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Test Panels'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildIntro(),
              const SizedBox(height: 16),
              _buildNewPanelButton(),
              const SizedBox(height: 20),
              if (_panels.isEmpty)
                _emptyState()
              else
                ..._panels.map(_buildPanelRow),
            ],
          ),
        ),
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
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
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
            child: const Icon(Icons.info_outline,
                color: AppColors.primaryDark, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What are panels?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'A panel is a reusable group of tests with fixed names, units, '
                      'and reference ranges (e.g. "CBC", "LFT", "Lipid Profile"). '
                      'When you add a panel to a visit, all its tests fill in '
                      'automatically — you only type the results.',
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

  Widget _buildNewPanelButton() {
    return ElevatedButton.icon(
      onPressed: _createNewPanel,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('New Panel'),
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
            child: const Icon(Icons.dashboard_customize_outlined,
                size: 32, color: AppColors.textFaint),
          ),
          const SizedBox(height: 14),
          const Text(
            'No panels yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Create your first panel (e.g. "CBC") and add its tests.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelRow(Panel panel) {
    final count = _testCounts[panel.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openPanel(panel),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  child: const Icon(Icons.dashboard_customize_outlined,
                      color: AppColors.primaryDark, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        panel.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count test${count == 1 ? "" : "s"}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete panel',
                  color: AppColors.error,
                  onPressed: () => _deletePanel(panel),
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
// New panel dialog
// -----------------------------------------------------------------------------

class _NewPanelDialog extends StatefulWidget {
  const _NewPanelDialog();

  @override
  State<_NewPanelDialog> createState() => _NewPanelDialogState();
}

class _NewPanelDialogState extends State<_NewPanelDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Panel'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Panel name',
            hintText: 'e.g. CBC, LFT, Lipid Profile',
            prefixIcon: Icon(Icons.dashboard_customize_outlined),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}