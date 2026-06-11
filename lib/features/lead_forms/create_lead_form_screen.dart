import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';
import '../../shared/widgets/fc_button.dart';

class CreateLeadFormScreen extends ConsumerStatefulWidget {
  const CreateLeadFormScreen({super.key});
  @override
  ConsumerState<CreateLeadFormScreen> createState() => _CreateLeadFormScreenState();
}

class _CreateLeadFormScreenState extends ConsumerState<CreateLeadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _redirectCtrl = TextEditingController();
  bool _captureEmail = true, _capturePhone = true, _captureCompany = false;
  bool _loading = false;

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); _redirectCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final fields = [
      {'name': 'full_name', 'label': 'Full Name', 'type': 'text', 'required': true},
      if (_captureEmail) {'name': 'email', 'label': 'Email', 'type': 'email', 'required': true},
      if (_capturePhone) {'name': 'phone', 'label': 'Phone', 'type': 'phone', 'required': false},
      if (_captureCompany) {'name': 'company', 'label': 'Company', 'type': 'text', 'required': false},
    ];
    try {
      await ApiClient().dio.post('/lead-forms', data: {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'fields': fields,
        if (_redirectCtrl.text.trim().isNotEmpty) 'redirectUrl': _redirectCtrl.text.trim(),
      });
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form created successfully'))); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLight,
    appBar: AppBar(title: const Text('Create Lead Form'), backgroundColor: Colors.white, foregroundColor: AppColors.textPrimary, elevation: 0),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20),
      child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Form Name *'),
          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
        const SizedBox(height: 14),
        TextFormField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)')),
        const SizedBox(height: 24),
        const Text('Fields to Capture', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        _buildField('Full Name', true, null, null),
        _buildField('Email Address', _captureEmail, null, (v) => setState(() => _captureEmail = v!)),
        _buildField('Phone Number', _capturePhone, null, (v) => setState(() => _capturePhone = v!)),
        _buildField('Company Name', _captureCompany, null, (v) => setState(() => _captureCompany = v!)),
        const SizedBox(height: 24),
        TextFormField(controller: _redirectCtrl, decoration: const InputDecoration(labelText: 'Redirect URL after submit (optional)', hintText: 'https://yoursite.com/thank-you')),
        const SizedBox(height: 28),
        FCButton(label: 'Create Form', loading: _loading, onPressed: _submit, icon: Icons.dynamic_form_outlined),
      ])),
    ),
  );

  Widget _buildField(String label, bool value, Function(bool?)? alwaysOn, Function(bool?)? onChanged) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
    value: value,
    onChanged: onChanged ?? ((_) {}),
    activeColor: AppColors.primary,
    controlAffinity: ListTileControlAffinity.leading,
  );
}
