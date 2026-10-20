import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/lab_test.dart';
import '../models/patient.dart';
import '../models/visit.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';

class ReportPreviewScreen extends StatefulWidget {
  final Patient patient;
  final Visit visit;
  final List<LabTest> tests;

  const ReportPreviewScreen({
    super.key,
    required this.patient,
    required this.visit,
    required this.tests,
  });

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  bool _saving = false;

  // ---- Group tests by section, preserving order ----
  Map<String, List<LabTest>> get _grouped {
    final Map<String, List<LabTest>> map = {};
    for (final t in widget.tests) {
      final key = t.section.isEmpty ? 'General' : t.section;
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  // ---- Comments = unique non-empty notes ----
  List<String> get _comments => widget.tests
      .map((t) => t.notes.trim())
      .where((n) => n.isNotEmpty)
      .toSet()
      .toList();

  // ---- Print ----
  Future<void> _print() async {
    try {
      await PdfService.printVisitReport(
        patient: widget.patient,
        visit: widget.visit,
        tests: widget.tests,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to print: $e')));
      }
    }
  }

  // ---- Save PDF to Downloads ----
  Future<void> _savePdf() async {
    setState(() => _saving = true);
    try {
      final file = await PdfService.saveVisitReportPdf(
        patient: widget.patient,
        visit: widget.visit,
        tests: widget.tests,
      );

      // Copy the temp file to Downloads with a friendly name
      final fileName =
          'Report_${widget.visit.pin.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf';

      String displayPath;
      if (!kIsWeb && Platform.isWindows) {
        final downloads = await getDownloadsDirectory();
        final targetDir = downloads ?? await getApplicationDocumentsDirectory();
        final target = File(
          '${targetDir.path}${Platform.pathSeparator}$fileName',
        );
        await file.copy(target.path);
        displayPath = target.path;
      } else {
        // Non-Windows: just report the temp path
        displayPath = file.path;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text('PDF saved to:\n$displayPath'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final p = widget.patient;
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Report Preview'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: _print,
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            tooltip: 'Save PDF to Downloads',
            onPressed: _saving ? null : _savePdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---- Report Header ----
                    _buildReportHeader(refNo: v.pin),
                    const SizedBox(height: 8),
                    const Divider(thickness: 1.4, color: AppColors.primaryDark),
                    const SizedBox(height: 14),

                    // ---- Patient Block ----
                    _buildPatientBlock(patient: p, visit: v),
                    const SizedBox(height: 20),

                    // ---- Sections + Tests ----
                    for (final section in grouped.keys) ...[
                      _buildSectionHeader(section),
                      const SizedBox(height: 8),
                      _buildTestTable(grouped[section]!),
                      const SizedBox(height: 16),
                    ],

                    // ---- Comments ----
                    if (_comments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          _comments.join('\n\n'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.text,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ---- Footer line ----
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Generated: ${DateTime.now().toString().substring(0, 16)}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          'PIN ${v.pin}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildReportHeader({required String refNo}) {
    return Row(
      children: [
        const Text(
          'Lab Report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const Spacer(),
        Text(
          'Ref #$refNo',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientBlock({required Patient patient, required Visit visit}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT COLUMN
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _previewInfoRow('Name', patient.name),
                const SizedBox(height: 6),
                _previewInfoRow(
                  'Phone',
                  patient.phone.isEmpty ? '-' : patient.phone,
                ),
                const SizedBox(height: 6),
                _previewInfoRow('PIN', visit.pin),
                const SizedBox(height: 6),
                _previewInfoRow(
                  'Address',
                  patient.address.isEmpty ? '-' : patient.address,
                ),
              ],
            ),
          ),
          // DIVIDER
          Container(
            width: 0.5,
            height: 100,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          // RIGHT COLUMN
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _previewInfoRow('Age', patient.age.isEmpty ? '-' : patient.age),
                const SizedBox(height: 6),
                _previewInfoRow(
                  'Gender',
                  patient.gender.isEmpty ? '-' : patient.gender,
                ),
                const SizedBox(height: 6),
                _previewInfoRow('Date', visit.displayDate),
                const SizedBox(height: 6),
                _previewInfoRow(
                  'Referred',
                  visit.referredBy.isEmpty ? '-' : visit.referredBy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTestTable(List<LabTest> tests) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: const [
                Expanded(flex: 3, child: _HeaderCell('Test Name')),
                Expanded(flex: 2, child: _HeaderCell('Result')),
                Expanded(flex: 2, child: _HeaderCell('Unit')),
                Expanded(flex: 3, child: _HeaderCell('Reference Range')),
              ],
            ),
          ),
          // Data rows
          for (int i = 0; i < tests.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      tests[i].testName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      tests[i].result.isEmpty ? '-' : tests[i].result,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      tests[i].unit.isEmpty ? '-' : tests[i].unit,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      tests[i].normalRange.isEmpty ? '-' : tests[i].normalRange,
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
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        letterSpacing: 0.2,
      ),
    );
  }
}
