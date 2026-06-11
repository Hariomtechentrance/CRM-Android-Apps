import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/widgets/fc_button.dart';
import '../../data/services/api_client.dart';

class AddDealScreen extends StatefulWidget {
  final Map<String, dynamic>? deal;
  const AddDealScreen({super.key, this.deal});
  @override
  State<AddDealScreen> createState() => _AddDealScreenState();
}

class _AddDealScreenState extends State<AddDealScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _titleCtrl  = TextEditingController();
  final _partyCtrl  = TextEditingController();
  final _valueCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _probCtrl   = TextEditingController(text: '50');
  String _stage     = 'PROSPECT';
  DateTime? _closeDate;
  bool _loading     = false;

  static const _purple  = Color(0xFF8B5CF6);
  static const _stages  = ['PROSPECT', 'QUALIFIED', 'PROPOSAL', 'NEGOTIATION', 'WON', 'LOST'];

  bool get _isEdit => widget.deal != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _populate();
  }

  void _populate() {
    final d = widget.deal!;
    _titleCtrl.text  = d['title']          ?? d['name'] ?? '';
    _partyCtrl.text  = d['party']?['name'] as String? ?? d['partyName'] ?? '';
    _valueCtrl.text  = (d['value']         ?? d['amount'] ?? '').toString();
    _descCtrl.text   = d['description']    ?? '';
    _sourceCtrl.text = d['source']         ?? '';
    _probCtrl.text   = (d['probability']   ?? 50).toString();
    _stage           = d['stage']          ?? 'PROSPECT';
    if (d['closeDate'] != null) {
      try { _closeDate = DateTime.parse(d['closeDate'] as String); } catch (_) {}
    }
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _partyCtrl, _valueCtrl, _descCtrl, _sourceCtrl, _probCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _closeDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _closeDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final data = {
      'title': _titleCtrl.text.trim(),
      'stage': _stage,
      if (_partyCtrl.text.trim().isNotEmpty)  'partyName':   _partyCtrl.text.trim(),
      if (_valueCtrl.text.trim().isNotEmpty)  'value':       double.tryParse(_valueCtrl.text) ?? 0,
      if (_descCtrl.text.trim().isNotEmpty)   'description': _descCtrl.text.trim(),
      if (_sourceCtrl.text.trim().isNotEmpty) 'source':      _sourceCtrl.text.trim(),
      if (_probCtrl.text.trim().isNotEmpty)   'probability': int.tryParse(_probCtrl.text) ?? 50,
      if (_closeDate != null) 'closeDate': _closeDate!.toIso8601String().substring(0, 10),
    };
    try {
      if (_isEdit) {
        await ApiClient().updateDeal(widget.deal!['id'] as String, data);
      } else {
        await ApiClient().createDeal(data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Deal updated' : 'Deal created'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      ));
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to save deal'),
        backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Deal' : 'New Deal'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _purple))
                : Text(_isEdit ? 'Update' : 'Save',
                    style: const TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _sec('Deal Info'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Deal Title *',
                prefixIcon: Icon(Icons.handshake_outlined, size: 18, color: AppColors.textGhost),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _partyCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Company / Party',
                prefixIcon: Icon(Icons.business_outlined, size: 18, color: AppColors.textGhost),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _valueCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Deal Value ₹',
                  prefixIcon: Icon(Icons.currency_rupee, size: 18, color: AppColors.textGhost),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _probCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Probability %',
                  prefixIcon: Icon(Icons.percent, size: 18, color: AppColors.textGhost),
                ),
              )),
            ]),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _stage,
              decoration: const InputDecoration(
                labelText: 'Stage',
                prefixIcon: Icon(Icons.account_tree_outlined, size: 18, color: AppColors.textGhost),
              ),
              items: _stages.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _stage = v!),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Expected Close Date',
                  prefixIcon: Icon(Icons.event_outlined, size: 18, color: AppColors.textGhost),
                ),
                child: Text(
                  _closeDate == null
                      ? 'Select date'
                      : '${_closeDate!.day.toString().padLeft(2, '0')}/${_closeDate!.month.toString().padLeft(2, '0')}/${_closeDate!.year}',
                  style: TextStyle(fontSize: 13, color: _closeDate == null ? AppColors.textGhost : AppColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _sourceCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Source',
                prefixIcon: Icon(Icons.ads_click_outlined, size: 18, color: AppColors.textGhost),
                hintText: 'e.g. Referral, Website, Trade Show',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description / Notes',
                prefixIcon: Icon(Icons.notes_outlined, size: 18, color: AppColors.textGhost),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),
            FCButton(label: _isEdit ? 'Update Deal' : 'Create Deal', loading: _loading, onPressed: _submit, color: _purple),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _sec(String label) => Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
}
