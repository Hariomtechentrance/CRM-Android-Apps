import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';
import '../../shared/widgets/fc_button.dart';

class AddPatientScreen extends ConsumerStatefulWidget {
  const AddPatientScreen({super.key});
  @override
  ConsumerState<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends ConsumerState<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _gender = 'MALE';
  String _bloodGroup = '';
  bool _loading = false;

  @override
  void dispose() { _nameCtrl.dispose(); _ageCtrl.dispose(); _phoneCtrl.dispose(); _addressCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiClient().dio.post('/health/patients', data: {
        'name': _nameCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text) ?? 0,
        'gender': _gender,
        'phone': _phoneCtrl.text.trim(),
        if (_bloodGroup.isNotEmpty) 'bloodGroup': _bloodGroup,
        if (_addressCtrl.text.trim().isNotEmpty) 'address': _addressCtrl.text.trim(),
      });
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient registered'))); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLight,
    appBar: AppBar(title: const Text('Register Patient'), backgroundColor: Colors.white, foregroundColor: AppColors.textPrimary, elevation: 0),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20),
      child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *'),
          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: TextFormField(controller: _ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age'))),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<String>(value: _gender, decoration: const InputDecoration(labelText: 'Gender'),
            items: const [DropdownMenuItem(value: 'MALE', child: Text('Male')), DropdownMenuItem(value: 'FEMALE', child: Text('Female')), DropdownMenuItem(value: 'OTHER', child: Text('Other'))],
            onChanged: (v) => setState(() => _gender = v!))),
        ]),
        const SizedBox(height: 14),
        TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(value: _bloodGroup.isEmpty ? null : _bloodGroup,
          decoration: const InputDecoration(labelText: 'Blood Group (optional)'),
          items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _bloodGroup = v ?? '')),
        const SizedBox(height: 14),
        TextFormField(controller: _addressCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Address (optional)')),
        const SizedBox(height: 28),
        FCButton(label: 'Register Patient', loading: _loading, onPressed: _submit, icon: Icons.person_add_outlined),
      ])),
    ),
  );
}
