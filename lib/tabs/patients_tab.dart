import 'package:flutter/material.dart';
import '../screens/patient_detail_screen.dart';
import '../db/database_service.dart';
import '../models/patient.dart';
import '../screens/patient_edit_screen.dart';
import '../theme/app_theme.dart';

class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key});

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  // Gender is now a dropdown, not a text field.
  String? _gender;

  static const List<String> _genderOptions = ['Male', 'Female', 'Other'];

  List<Patient> _patients = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _searchQuery = _searchCtrl.text.trim();
      _loadPatients();
    });
    _loadPatients();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _loading = true);
    final patients = await DatabaseService.instance.getPatients(
      query: _searchQuery,
    );
    if (mounted) {
      setState(() {
        _patients = patients;
        _loading = false;
      });
    }
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;
    final patient = Patient(
      name: _nameCtrl.text.trim(),
      age: _ageCtrl.text.trim(),
      gender: _gender ?? '',
      // dropdown value (empty if not chosen)
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      dateAdded: DateTime.now().toString().substring(0, 16),
    );
    try {
      await DatabaseService.instance.insertPatient(patient);
      _clearForm();
      await _loadPatients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Patient "${patient.name}" saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  void _clearForm() {
    _nameCtrl.clear();
    _ageCtrl.clear();
    _phoneCtrl.clear();
    _addressCtrl.clear();
    setState(() => _gender = null);
  }

  Future<void> _deletePatient(Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete patient?'),
        content: Text(
          'Delete "${patient.name}" and all their lab reports? This cannot be undone.',
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
        await DatabaseService.instance.deletePatient(patient.id!);
        await _loadPatients();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  Future<void> _editPatient(Patient patient) async {
    final updated = await Navigator.push<Patient>(
      context,
      MaterialPageRoute(builder: (_) => PatientEditScreen(patient: patient)),
    );
    if (updated != null) {
      await _loadPatients();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFormCard(),
          const SizedBox(height: 20),
          _buildSearchField(),
          const SizedBox(height: 12),
          _buildPatientList(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Add New Patient',
                subtitle: 'Register a new patient record',
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
                    onPressed: _savePatient,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save Patient'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _clearForm,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
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

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Search patients by name or phone…',
        prefixIcon: const Icon(Icons.search),
        fillColor: AppColors.surface,
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                },
              ),
      ),
    );
  }

  Widget _buildPatientList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_patients.isEmpty) {
      return _EmptyState(
        icon: _searchQuery.isEmpty
            ? Icons.people_outline
            : Icons.search_off_outlined,
        title: _searchQuery.isEmpty ? 'No patients yet' : 'No matches',
        subtitle: _searchQuery.isEmpty
            ? 'Add your first patient using the form above.'
            : 'Try a different name or phone number.',
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Row(
            children: [
              Text(
                '${_patients.length} patient${_patients.length == 1 ? "" : "s"}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        ..._patients.map(_buildPatientRow),
      ],
    );
  }

  Widget _buildPatientRow(Patient p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PatientDetailScreen(patient: p),
              ),
            );
            // If the detail screen returned 'edit', open the edit form.
            if (result == 'edit' && mounted) {
              final updated = await Navigator.push<Patient>(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientEditScreen(patient: p),
                ),
              );
              if (updated != null) {
                await _loadPatients();
              }
            } else {
              await _loadPatients();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _Avatar(letter: p.name.isNotEmpty ? p.name[0] : '?'),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (p.age.isNotEmpty)
                            _MetaChip(
                              icon: Icons.cake_outlined,
                              text: 'Age ${p.age}',
                            ),
                          if (p.gender.isNotEmpty)
                            _MetaChip(icon: Icons.wc_outlined, text: p.gender),
                          if (p.phone.isNotEmpty)
                            _MetaChip(
                              icon: Icons.phone_outlined,
                              text: p.phone,
                            ),
                        ],
                      ),
                      if (p.address.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          p.address,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
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
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit patient',
                  color: AppColors.primary,
                  onPressed: () => _editPatient(p),
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete patient',
                  color: AppColors.error,
                  onPressed: () => _deletePatient(p),
                ),
                // Chevron hint so users know the row is tappable
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textFaint,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Small shared widgets (used here and in other tabs)
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

class _Avatar extends StatelessWidget {
  final String letter;

  const _Avatar({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        letter.toUpperCase(),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

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
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.textFaint),
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
      ),
    );
  }
}
