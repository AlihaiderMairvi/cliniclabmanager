import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_service.dart';
import '../models/lab_test.dart';
import '../models/patient.dart';
import '../models/visit.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';

const List<String> _paymentModes = [
  'Cash',
  'Card',
  'Easypaisa',
  'JazzCash',
  'Bank Transfer',
  'Credit',
];

class InvoiceScreen extends StatefulWidget {
  final Visit visit;
  final Patient patient;

  const InvoiceScreen({
    super.key,
    required this.visit,
    required this.patient,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  List<LabTest> _tests = [];
  bool _loading = true;
  bool _saving = false;

  // Local (fresh) copy of the visit — reloaded from the DB on init.
  late Visit _visit;

  double _discount = 0;
  double _amountReceived = 0;
  String _paymentMode = 'Cash';
  String _invoiceNotes = '';

  final _discountCtrl = TextEditingController();
  final _receivedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _visit = widget.visit;
    _load();
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _receivedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Always re-fetch the visit so we see the latest saved invoice fields.
    final freshVisit =
    await DatabaseService.instance.getVisit(widget.visit.id!);
    final tests =
    await DatabaseService.instance.getTestsForVisit(widget.visit.id!);
    if (!mounted) return;

    final v = freshVisit ?? widget.visit;
    setState(() {
      _visit = v;
      _tests = tests;
      _discount = v.discount;
      _amountReceived = v.amountReceived;
      _paymentMode = v.paymentMode.isEmpty ? 'Cash' : v.paymentMode;
      _invoiceNotes = v.invoiceNotes;

      _discountCtrl.text = _discount > 0 ? _discount.toStringAsFixed(0) : '';
      _receivedCtrl.text =
      _amountReceived > 0 ? _amountReceived.toStringAsFixed(0) : '';
      _notesCtrl.text = _invoiceNotes;

      _loading = false;
    });
  }

  // ---- Totals ----
  double get _subtotal => _tests.fold(0.0, (s, t) => s + t.price);
  double get _netPayable {
    final v = _subtotal - _discount;
    return v < 0 ? 0.0 : v;
  }
  double get _balance => _netPayable - _amountReceived;
  bool get _isPaidInFull => _netPayable > 0 && _amountReceived >= _netPayable;

  // ---- Save invoice fields ----
  Future<void> _saveInvoiceFields({bool silent = false}) async {
    if (!silent) setState(() => _saving = true);
    try {
      await DatabaseService.instance.updateVisitInvoice(
        visitId: _visit.id!,
        discount: _discount,
        amountReceived: _amountReceived,
        paymentMode: _paymentMode,
        invoiceNotes: _invoiceNotes,
      );
      // Refresh so the local `_visit` picks up the new values.
      final fresh = await DatabaseService.instance.getVisit(_visit.id!);
      if (fresh != null && mounted) {
        setState(() => _visit = fresh);
      }
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (!silent && mounted) setState(() => _saving = false);
    }
  }

  // ---- Print invoice ----
  Future<void> _printInvoice() async {
    try {
      await _saveInvoiceFields(silent: true);

      await PdfService.printInvoice(
        patient: widget.patient,
        visit: _visit,
        tests: _tests,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to print: $e')),
        );
      }
    }
  }

  // ---- Save PDF to Downloads ----
  Future<void> _savePdf() async {
    setState(() => _saving = true);
    try {
      await _saveInvoiceFields(silent: true);

      final path = await PdfService.saveInvoiceToDownloads(
        patient: widget.patient,
        visit: _visit,
        tests: _tests,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text('Invoice saved to:\n$path'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invoice'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.save_outlined),
            tooltip: 'Save invoice',
            onPressed: _loading || _saving ? null : _saveInvoiceFields,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print invoice',
            onPressed: _loading ? null : _printInvoice,
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Save PDF to Downloads',
            onPressed: _loading || _saving ? null : _savePdf,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 16),
                _buildTestsTable(),
                const SizedBox(height: 16),
                _buildTotalsCard(),
                const SizedBox(height: 16),
                _buildPaymentCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildHeaderCard() {
    final v = _visit;
    final p = widget.patient;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Invoice  ·  PIN ${v.pin}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                // Status badge (Paid / Pending) — driven by payment
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isPaidInFull
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPaidInFull
                            ? Icons.check_circle_outline
                            : Icons.schedule,
                        size: 14,
                        color: _isPaidInFull
                            ? const Color(0xFF065F46)
                            : const Color(0xFF92400E),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isPaidInFull ? 'PAID' : 'PENDING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: _isPaidInFull
                              ? const Color(0xFF065F46)
                              : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoLine('Patient', p.name),
            if (p.phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              _infoLine('Phone', p.phone),
            ],
            const SizedBox(height: 4),
            _infoLine('Referred by', v.referredBy),
            const SizedBox(height: 4),
            _infoLine('Date', v.displayDate),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
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

  Widget _buildTestsTable() {
    if (_tests.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: const [
              Icon(Icons.info_outline,
                  size: 32, color: AppColors.textFaint),
              SizedBox(height: 10),
              Text(
                'No tests in this visit.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 5, child: _HeaderCell('Test Name')),
                Expanded(
                    flex: 2,
                    child: _HeaderCell('Rate', align: TextAlign.right)),
                Expanded(
                    flex: 1,
                    child: _HeaderCell('Qty', align: TextAlign.center)),
                Expanded(
                    flex: 3,
                    child: _HeaderCell('Amount', align: TextAlign.right)),
              ],
            ),
          ),
          for (int i = 0; i < _tests.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tests[i].testName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        if (_tests[i].section.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _tests[i].section,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Rs ${_tests[i].price.toStringAsFixed(0)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 1,
                    child: Text(
                      '1',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Rs ${_tests[i].price.toStringAsFixed(0)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
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

  Widget _buildTotalsCard() {
    final subtotal = _subtotal;
    final net = _netPayable;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _totalRow('Subtotal', subtotal),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: Text(
                    'Discount (Rs)',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: false),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      hintText: '0',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _discount = double.tryParse(v.trim()) ?? 0;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: Text(
                    'Net Payable',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Rs ${net.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, double amount) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'Rs ${amount.toStringAsFixed(0)}',
            textAlign: TextAlign.right,
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

  Widget _buildPaymentCard() {
    final balance = _balance;
    final balancePositive = balance > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: Text(
                    'Amount received (Rs)',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _receivedCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: false),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      hintText: '0',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _amountReceived = double.tryParse(v.trim()) ?? 0;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _paymentMode,
              decoration: const InputDecoration(
                labelText: 'Payment mode',
                prefixIcon: Icon(Icons.payment_outlined),
              ),
              items: _paymentModes
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _paymentMode = v);
              },
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Invoice notes (optional)',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              onChanged: (v) => _invoiceNotes = v,
            ),
            const SizedBox(height: 16),

            // Balance indicator
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: balancePositive
                    ? AppColors.error.withValues(alpha: 0.10)
                    : AppColors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: balancePositive
                      ? AppColors.error.withValues(alpha: 0.4)
                      : AppColors.success.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    balancePositive
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: balancePositive
                        ? AppColors.error
                        : AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    balancePositive ? 'Balance due' : 'Paid in full',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: balancePositive
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Rs ${balance.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: balancePositive
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _HeaderCell(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        letterSpacing: 0.2,
      ),
    );
  }
}