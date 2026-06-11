import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/widgets/fc_button.dart';
import '../../data/services/api_client.dart';

class AddGoodsEntryScreen extends StatefulWidget {
  final Map<String, dynamic>? entry;
  const AddGoodsEntryScreen({super.key, this.entry});
  @override
  State<AddGoodsEntryScreen> createState() => _AddGoodsEntryScreenState();
}

class _AddGoodsEntryScreenState extends State<AddGoodsEntryScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _grnCtrl       = TextEditingController();
  final _supplierCtrl  = TextEditingController();
  final _poCtrl        = TextEditingController();
  final _warehouseCtrl = TextEditingController();
  final _notesCtrl     = TextEditingController();
  String _status       = 'RECEIVED';
  DateTime _date       = DateTime.now();
  bool _loading        = false;
  final List<Map<String, dynamic>> _items = [];

  static const _statuses = ['PENDING', 'RECEIVED', 'PARTIAL', 'REJECTED'];

  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _populate();
    else _addItem();
  }

  void _populate() {
    final e = widget.entry!;
    _grnCtrl.text       = e['grnNumber']    ?? '';
    _supplierCtrl.text  = e['supplierName'] ?? e['supplier']?['name'] ?? '';
    _poCtrl.text        = e['poNumber']     ?? '';
    _warehouseCtrl.text = e['warehouse']    ?? '';
    _notesCtrl.text     = e['notes']        ?? '';
    _status             = e['status']       ?? 'RECEIVED';
    final items = e['items'] as List? ?? [];
    for (final item in items) {
      _items.add({
        'nameCtrl':  TextEditingController(text: item['productName'] ?? ''),
        'skuCtrl':   TextEditingController(text: item['sku'] ?? ''),
        'qtyCtrl':   TextEditingController(text: (item['quantity'] ?? 1).toString()),
        'priceCtrl': TextEditingController(text: (item['unitPrice'] ?? 0).toString()),
      });
    }
    if (_items.isEmpty) _addItem();
  }

  @override
  void dispose() {
    for (final c in [_grnCtrl, _supplierCtrl, _poCtrl, _warehouseCtrl, _notesCtrl]) c.dispose();
    for (final item in _items) {
      (item['nameCtrl'] as TextEditingController).dispose();
      (item['skuCtrl'] as TextEditingController).dispose();
      (item['qtyCtrl'] as TextEditingController).dispose();
      (item['priceCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add({
      'nameCtrl':  TextEditingController(),
      'skuCtrl':   TextEditingController(),
      'qtyCtrl':   TextEditingController(text: '1'),
      'priceCtrl': TextEditingController(text: '0'),
    }));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    final item = _items[index];
    (item['nameCtrl'] as TextEditingController).dispose();
    (item['skuCtrl'] as TextEditingController).dispose();
    (item['qtyCtrl'] as TextEditingController).dispose();
    (item['priceCtrl'] as TextEditingController).dispose();
    setState(() => _items.removeAt(index));
  }

  double get _totalValue => _items.fold(0, (s, item) {
    final qty   = double.tryParse((item['qtyCtrl'] as TextEditingController).text)   ?? 0;
    final price = double.tryParse((item['priceCtrl'] as TextEditingController).text) ?? 0;
    return s + qty * price;
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final itemsList = _items.map((item) => {
      'productName': (item['nameCtrl'] as TextEditingController).text.trim(),
      'sku':         (item['skuCtrl'] as TextEditingController).text.trim(),
      'quantity':    double.tryParse((item['qtyCtrl'] as TextEditingController).text) ?? 1,
      'unitPrice':   double.tryParse((item['priceCtrl'] as TextEditingController).text) ?? 0,
    }).toList();
    final data = {
      'supplierName': _supplierCtrl.text.trim(),
      'status':       _status,
      'date':         _date.toIso8601String().substring(0, 10),
      'totalValue':   _totalValue,
      'items':        itemsList,
      if (_grnCtrl.text.trim().isNotEmpty)       'grnNumber':  _grnCtrl.text.trim(),
      if (_poCtrl.text.trim().isNotEmpty)        'poNumber':   _poCtrl.text.trim(),
      if (_warehouseCtrl.text.trim().isNotEmpty) 'warehouse':  _warehouseCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty)     'notes':      _notesCtrl.text.trim(),
    };
    try {
      if (_isEdit) {
        await ApiClient().dio.patch('/store/goods-entries/${widget.entry!['id']}', data: data);
      } else {
        await ApiClient().dio.post('/store/goods-entries', data: data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Entry updated' : 'Goods entry created'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      ));
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to save entry'),
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
        title: Text(_isEdit ? 'Edit GRN' : 'New Goods Entry'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success))
                : Text(_isEdit ? 'Update' : 'Save',
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _sec('Receipt Info'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _supplierCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Supplier Name *',
                prefixIcon: Icon(Icons.business_outlined, size: 18, color: AppColors.textGhost),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Supplier required' : null,
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _grnCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'GRN Number',
                  prefixIcon: Icon(Icons.receipt_outlined, size: 18, color: AppColors.textGhost)),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _poCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'PO Reference',
                  prefixIcon: Icon(Icons.link_outlined, size: 18, color: AppColors.textGhost)),
              )),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Receipt Date',
                    prefixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textGhost),
                  ),
                  child: Text(
                    '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() => _status = v!),
              )),
            ]),
            const SizedBox(height: 14),
            TextFormField(
              controller: _warehouseCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Warehouse / Location',
                prefixIcon: Icon(Icons.warehouse_outlined, size: 18, color: AppColors.textGhost),
              ),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _sec('Items'),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 16, color: AppColors.success),
                label: const Text('Add Item', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),
            ...List.generate(_items.length, (i) => _ItemRow(
              index: i,
              item: _items[i],
              onRemove: () => _removeItem(i),
              onChanged: () => setState(() {}),
            )),
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withOpacity(0.2)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total Value', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSec)),
                Text('₹${_totalValue.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.success)),
              ]),
            ),
            _sec('Notes'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes / Remarks',
                prefixIcon: Icon(Icons.notes_outlined, size: 18, color: AppColors.textGhost),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),
            FCButton(label: _isEdit ? 'Update Entry' : 'Create Goods Entry', loading: _loading, onPressed: _submit, color: AppColors.success),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _sec(String label) => Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
}

class _ItemRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> item;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _ItemRow({required this.index, required this.item, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final qtyCtrl   = item['qtyCtrl']   as TextEditingController;
    final priceCtrl = item['priceCtrl'] as TextEditingController;
    final subtotal  = (double.tryParse(qtyCtrl.text) ?? 0) * (double.tryParse(priceCtrl.text) ?? 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(children: [
          Text('Item ${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSec)),
          const Spacer(),
          InkWell(onTap: onRemove, child: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.danger)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(flex: 3, child: TextFormField(
            controller: item['nameCtrl'] as TextEditingController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'Product *', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          )),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: TextFormField(
            controller: item['skuCtrl'] as TextEditingController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'SKU', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextFormField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'Qty *', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            validator: (v) => (v == null || double.tryParse(v) == null) ? 'Invalid' : null,
          )),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'Unit Price ₹', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          )),
          const SizedBox(width: 8),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withOpacity(0.2)),
            ),
            child: Text('₹${subtotal.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
              textAlign: TextAlign.center),
          )),
        ]),
      ]),
    );
  }
}
