import 'package:flutter/material.dart';

import '../db/database_service.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';

class PatientEditScreen extends StatefulWidget {
  final Patient patient;

  const PatientEditScreen({super.key, required this.patient});

  @override
  State<PatientEditScreen> createState() => _PatientEditScreenState();
}

class _PatientEditScreenState extends State<PatientEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;

  String? _gender;
  bool _saving = false;

  static const List<String> _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _nameCtrl = TextEditingController(text: p.name);
    _ageCtrl = TextEditingController(text: p.age);
    _phoneCtrl = TextEditingController(text: p.phone);
    _addressCtrl = TextEditingController(text: p.address);
    _gender = p.gender.isEmpty ? null : p.gender;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final updated = Patient(
      id: widget.patient.id,
      name: _nameCtrl.text.trim(),
      age: _ageCtrl.text.trim(),
      gender: _gender ?? '',
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      dateAdded: widget.patient.dateAdded, // keep original
    );

    try {
      await DatabaseService.instance.updatePatient(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Patient "${updated.name}" updated.')),
      );
      Navigator.pop(context, updated); // return the updated patient
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Patient'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    icon: Icons.edit_outlined,
                    title: 'Patient Information',
                    subtitle: 'Update the patient\'s details',
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 640;
                      return Column(
                        children: [
                          if (wide)
                            Row(
                              children: [
                                Expanded(flex: 2, child: _nameField()),
                                const SizedBox(width: 14),
                                Expanded(flex: 1, child: _ageField()),
                              ],
                            )
                          else ...[
                            _nameField(),
                            const SizedBox(height: 14),
                            _ageField(),
                          ],
                          const SizedBox(height: 14),
                          if (wide)
                            Row(
                              children: [
                                Expanded(child: _genderField()),
                                const SizedBox(width: 14),
                                Expanded(child: _phoneField()),
                              ],
                            )
                          else ...[
                            _genderField(),
                            const SizedBox(height: 14),
                            _phoneField(),
                          ],
                          const SizedBox(height: 14),
                          _addressField(),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
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
                        label: Text(_saving ? 'Saving…' : 'Save Changes'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed:
                        _saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameField() => TextFormField(
    controller: _nameCtrl,
    decoration: const InputDecoration(
      labelText: 'Full name *',
      prefixIcon: Icon(Icons.person_outline),
    ),
    validator: (v) =>
    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
  );

  Widget _ageField() => TextFormField(
    controller: _ageCtrl,
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(
      labelText: 'Age',
      prefixIcon: Icon(Icons.cake_outlined),
    ),
  );

  Widget _genderField() => DropdownButtonFormField<String>(
    initialValue: _gender,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Gender',
      prefixIcon: Icon(Icons.wc_outlined),
    ),
    items: _genderOptions
        .map((g) => DropdownMenuItem<String>(value: g, child: Text(g)))
        .toList(),
    onChanged: (v) => setState(() => _gender = v),
  );

  Widget _phoneField() => TextFormField(
    controller: _phoneCtrl,
    keyboardType: TextInputType.phone,
    decoration: const InputDecoration(
      labelText: 'Phone',
      prefixIcon: Icon(Icons.phone_outlined),
    ),
  );

  Widget _addressField() => TextFormField(
    controller: _addressCtrl,
    decoration: const InputDecoration(
      labelText: 'Address',
      prefixIcon: Icon(Icons.home_outlined),
    ),
  );
}

// -----------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}