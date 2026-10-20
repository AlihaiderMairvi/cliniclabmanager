import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_service.dart';
import '../models/patient.dart';
import '../models/visit.dart';
import '../models/lab_test.dart';
import '../models/panel.dart';
import '../models/panel_test.dart';
import '../theme/app_theme.dart';

/// One entry in the form — a single test row.
class _TestDraft {
  final TextEditingController testName = TextEditingController();
  final TextEditingController result = TextEditingController();
  final TextEditingController unit = TextEditingController();
  final TextEditingController normalRange = TextEditingController();
  final TextEditingController notes = TextEditingController();
  final TextEditingController price = TextEditingController();
  String status = 'Pending';

  void dispose() {
    testName.dispose();
    result.dispose();
    unit.dispose();
    normalRange.dispose();
    notes.dispose();
    price.dispose();
  }

  bool get isEmpty =>
      testName.text.trim().isEmpty &&
          result.text.trim().isEmpty &&
          unit.text.trim().isEmpty &&
          normalRange.text.trim().isEmpty &&
          notes.text.trim().isEmpty &&
          price.text.trim().isEmpty;

  double get priceValue => double.tryParse(price.text.trim()) ?? 0;
}

/// One section — a labeled group of tests (e.g. "Lab", "Radiology").
class _SectionDraft {
  final TextEditingController name;
  final List<_TestDraft> tests;

  _SectionDraft({String sectionName = ''})
      : name = TextEditingController(text: sectionName),
        tests = [];

  void dispose() {
    name.dispose();
    for (final t in tests) {
      t.dispose();
    }
  }
}

class AddVisitScreen extends StatefulWidget {
  final Patient patient;

  const AddVisitScreen({super.key, required this.patient});

  @override
  State<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referredByCtrl = TextEditingController(text: 'Self');

  final List<_SectionDraft> _sections = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = _SectionDraft(sectionName: 'Lab');
    s.tests.add(_TestDraft());
    _sections.add(s);
  }

  @override
  void dispose() {
    _referredByCtrl.dispose();
    for (final s in _sections) {
      s.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Section/test manipulation
  // ---------------------------------------------------------------------------

  void _addTestToSection(int sectionIndex) {
    setState(() {
      _sections[sectionIndex].tests.add(_TestDraft());
    });
  }

  void _removeTestFromSection(int sectionIndex, int testIndex) {
    setState(() {
      final t = _sections[sectionIndex].tests.removeAt(testIndex);
      t.dispose();
    });
  }

  void _addSection() {
    setState(() {
      final s = _SectionDraft(sectionName: '');
      s.tests.add(_TestDraft());
      _sections.add(s);
    });
  }

  void _removeSection(int sectionIndex) {
    setState(() {
      final s = _sections.removeAt(sectionIndex);
      s.dispose();
    });
  }

  // ---------------------------------------------------------------------------
  // Panel picker + insertion
  // ---------------------------------------------------------------------------

  Future<void> _addPanelToSection(int sectionIndex) async {
    final panels = await DatabaseService.instance.getPanels();
    if (!mounted) return;

    if (panels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No panels yet. Create one from the Test Panels screen first.',
          ),
        ),
      );
      return;
    }

    final chosen = await showModalBottomSheet<Panel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PanelPickerSheet(panels: panels),
    );
    if (chosen == null) return;

    final panelTests =
    await DatabaseService.instance.getPanelTests(chosen.id!);
    if (!mounted) return;

    if (panelTests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Panel "${chosen.name}" has no tests.')),
      );
      return;
    }

    setState(() {
      final section = _sections[sectionIndex];

      // Remove fully-empty draft rows before inserting the panel's tests.
      section.tests.removeWhere((t) {
        if (t.isEmpty) {
          t.dispose();
          return true;
        }
        return false;
      });

      for (final pt in panelTests) {
        final d = _TestDraft();
        d.testName.text = pt.testName;
        d.unit.text = pt.unit;
        d.normalRange.text = pt.normalRange;
        if (pt.price > 0) {
          d.price.text = pt.price.toStringAsFixed(0);
        }
        section.tests.add(d);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${panelTests.length} test${panelTests.length == 1 ? "" : "s"} '
              'from "${chosen.name}".',
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Totals
  // ---------------------------------------------------------------------------

  double get _grandTotal {
    double total = 0;
    for (final s in _sections) {
      for (final t in s.tests) {
        if (t.isEmpty) continue;
        total += t.priceValue;
      }
    }
    return total;
  }

  int get _validTestCount {
    int count = 0;
    for (final s in _sections) {
      for (final t in s.tests) {
        if (!t.isEmpty) count++;
      }
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _saveVisit() async {
    if (!_formKey.currentState!.validate()) return;

    final List<_ResolvedTest> resolved = [];
    for (final section in _sections) {
      final sectionName = section.name.text.trim();
      for (final t in section.tests) {
        if (t.isEmpty) continue;
        if (t.testName.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Each test must have a name.')),
          );
          return;
        }
        resolved.add(_ResolvedTest(section: sectionName, test: t));
      }
    }

    if (resolved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one test before saving.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      String pin = '';
      int visitId = -1;

      // Try up to 5 times to generate a unique PIN (prevents UNIQUE constraint crashes)
      for (int attempt = 0; attempt < 5; attempt++) {
        pin = await DatabaseService.instance.generatePin(at: now);
        final visit = Visit(
          patientId: widget.patient.id!,
          pin: pin,
          visitDate: _formatDateTime(now),
          referredBy: _referredByCtrl.text.trim().isEmpty
              ? 'Self'
              : _referredByCtrl.text.trim(),
          createdAt: now.toIso8601String(),
        );

        try {
          visitId = await DatabaseService.instance.insertVisit(visit);
          break; // Success! Break out of the loop.
        } catch (e) {
          if (!e.toString().contains('UNIQUE')) {
            rethrow; // It's a real error, not a PIN collision.
          }
          // PIN collided, loop will try the next number.
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      if (visitId == -1) {
        throw StateError('Could not generate a unique PIN.');
      }

      // Now insert the tests using the successful visitId
      for (final r in resolved) {
        final t = LabTest(
          visitId: visitId,
          section: r.section,
          testName: r.test.testName.text.trim(),
          result: r.test.result.text.trim(),
          unit: r.test.unit.text.trim(),
          normalRange: r.test.normalRange.text.trim(),
          notes: r.test.notes.text.trim(),
          price: r.test.priceValue,
          // Removed 'status' and 'reportingTime' since we removed them from the UI
        );
        await DatabaseService.instance.insertTest(t);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visit $pin saved.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  String _formatDateTime(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Visit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPatientBanner(p),
              const SizedBox(height: 16),
              _buildVisitInfoCard(),
              const SizedBox(height: 16),
              for (int i = 0; i < _sections.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildSectionCard(i),
                ),
              OutlinedButton.icon(
                onPressed: _saving ? null : _addSection,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add another section'),
              ),
              const SizedBox(height: 16),
              _buildGrandTotalBar(),
              const SizedBox(height: 20),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _saveVisit,
                    icon: _saving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Saving…' : 'Save Visit'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed:
                    _saving ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Patient banner
  // ---------------------------------------------------------------------------

  Widget _buildPatientBanner(Patient p) {
    final initial = p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';
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
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adding visit for',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                if (p.age.isNotEmpty ||
                    p.gender.isNotEmpty ||
                    p.phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        if (p.age.isNotEmpty) 'Age ${p.age}',
                        if (p.gender.isNotEmpty) p.gender,
                        if (p.phone.isNotEmpty) p.phone,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Visit info card
  // ---------------------------------------------------------------------------

  Widget _buildVisitInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_note_outlined,
                      color: AppColors.primaryDark, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Visit Information',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text)),
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text('Who referred this patient?',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.textMuted)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _referredByCtrl,
              decoration: const InputDecoration(
                labelText: 'Referred by',
                hintText: 'Self or doctor name',
                prefixIcon: Icon(Icons.local_hospital_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section card
  // ---------------------------------------------------------------------------

  Widget _buildSectionCard(int sectionIndex) {
    final section = _sections[sectionIndex];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.category_outlined,
                      color: AppColors.primaryDark, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: section.name,
                    decoration: const InputDecoration(
                      labelText: 'Section name',
                      hintText: 'e.g. Lab, Thyroid Function Tests',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_sections.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.error,
                    tooltip: 'Remove section',
                    onPressed: _saving
                        ? null
                        : () => _removeSection(sectionIndex),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _addPanelToSection(sectionIndex),
                  icon: const Icon(Icons.library_add_outlined, size: 18),
                  label: const Text('Add Panel'),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed:
                  _saving ? null : () => _addTestToSection(sectionIndex),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add single test'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < section.tests.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTestRow(sectionIndex, i),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Test row (now includes Price)
  // ---------------------------------------------------------------------------

  Widget _buildTestRow(int sectionIndex, int testIndex) {
    final t = _sections[sectionIndex].tests[testIndex];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Test ${testIndex + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              if (_sections[sectionIndex].tests.length > 1)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.error,
                  tooltip: 'Remove test',
                  onPressed: _saving
                      ? null
                      : () => _removeTestFromSection(sectionIndex, testIndex),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Test name + result
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 640;
            final nameField = TextFormField(
              controller: t.testName,
              decoration: const InputDecoration(
                labelText: 'Test name *',
                prefixIcon: Icon(Icons.science_outlined),
              ),
            );
            final resultField = TextFormField(
              controller: t.result,
              decoration: const InputDecoration(
                labelText: 'Result',
                prefixIcon: Icon(Icons.numbers),
              ),
            );
            if (wide) {
              return Row(children: [
                Expanded(flex: 2, child: nameField),
                const SizedBox(width: 14),
                Expanded(child: resultField),
              ]);
            }
            return Column(children: [
              nameField,
              const SizedBox(height: 12),
              resultField,
            ]);
          }),
          const SizedBox(height: 12),

          // Unit + range
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 640;
            final unitField = TextFormField(
              controller: t.unit,
              decoration: const InputDecoration(
                labelText: 'Unit',
                prefixIcon: Icon(Icons.straighten_outlined),
              ),
            );
            final rangeField = TextFormField(
              controller: t.normalRange,
              decoration: const InputDecoration(
                labelText: 'Normal range',
                prefixIcon: Icon(Icons.rule_outlined),
              ),
            );
            if (wide) {
              return Row(children: [
                Expanded(child: unitField),
                const SizedBox(width: 14),
                Expanded(child: rangeField),
              ]);
            }
            return Column(children: [
              unitField,
              const SizedBox(height: 12),
              rangeField,
            ]);
          }),
          const SizedBox(height: 12),

          // Price + Notes
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 640;
            final priceField = TextFormField(
              controller: t.price,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (_) => setState(() {}), // update total
              decoration: const InputDecoration(
                labelText: 'Price (Rs)',
                hintText: 'e.g. 500',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            );
            final notesField = TextFormField(
              controller: t.notes,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            );
            if (wide) {
              return Row(children: [
                Expanded(flex: 1, child: priceField),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: notesField),
              ]);
            }
            return Column(children: [
              priceField,
              const SizedBox(height: 12),
              notesField,
            ]);
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Grand total bar
  // ---------------------------------------------------------------------------

  Widget _buildGrandTotalBar() {
    final count = _validTestCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.primaryDark, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count test${count == 1 ? "" : "s"} in this visit',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Rs ${_grandTotal.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Panel picker bottom sheet
// -----------------------------------------------------------------------------

class _PanelPickerSheet extends StatelessWidget {
  final List<Panel> panels;
  const _PanelPickerSheet({required this.panels});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pick a panel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Its tests will be inserted into this section.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: panels.length,
              itemBuilder: (context, i) {
                final p = panels[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                  Icons.dashboard_customize_outlined,
                                  size: 20,
                                  color: AppColors.primaryDark),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppColors.textFaint, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _ResolvedTest {
  final String section;
  final _TestDraft test;
  _ResolvedTest({required this.section, required this.test});
}