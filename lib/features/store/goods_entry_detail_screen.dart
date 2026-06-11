import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';

class GoodsEntryDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const GoodsEntryDetailScreen({super.key, required this.id});
  @override
  ConsumerState<GoodsEntryDetailScreen> createState() => _GoodsEntryDetailScreenState();
}

class _GoodsEntryDetailScreenState extends ConsumerState<GoodsEntryDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _entry;
  final _fmt = NumberFormat('#,##,###', 'en_IN');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get('/store/goods-entries/${widget.id}');
      final raw = res.data['data'];
      if (!mounted) return;
      setState(() => _entry = raw is Map ? Map<String, dynamic>.from(raw as Map) : null);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _cs() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Coming soon'), behavior: SnackBarBehavior.floating));

  Color _statusColor(String? s) {
    switch (s) {
      case 'RECEIVED': return AppColors.success;
      case 'PENDING':  return AppColors.warning;
      case 'REJECTED': return AppColors.danger;
      case 'PARTIAL':  return AppColors.info;
      default:         return AppColors.textGhost;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.success)));
    if (_entry == null) return Scaffold(
      appBar: AppBar(title: const Text('Entry Detail')),
      body: const Center(child: Text('Entry not found', style: TextStyle(color: AppColors.textGhost))),
    );

    final e = _entry!;
    final status = e['status'] as String? ?? 'PENDING';
    final statusColor = _statusColor(status);
    final items = e['items'] as List? ?? [];
    final totalValue = (e['totalValue'] as num? ?? 0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(e['grnNumber'] as String? ?? 'GRN Detail'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () async {
            final result = await context.push<bool>('/store/edit', extra: e);
            if (result == true) _load();
          }),
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: _cs),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.success,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [statusColor, statusColor.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.move_to_inbox_outlined, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(e['grnNumber'] as String? ?? 'GRN', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                    child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 12),
                Text('₹${_fmt.format(totalValue)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 4),
                Text(e['supplierName'] as String? ?? 'Supplier', style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 16),
            _infoCard([
              _row('Supplier',  e['supplierName']  as String? ?? '—'),
              _row('Date',      e['date']          as String? ?? e['createdAt'] as String? ?? '—'),
              _row('PO Ref',    e['poNumber']      as String? ?? '—'),
              _row('Warehouse', e['warehouse']     as String? ?? '—'),
              if ((e['notes'] as String? ?? '').isNotEmpty)
                _row('Notes', e['notes'] as String),
            ]),
            const SizedBox(height: 16),
            const Text('Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: const Text('No items recorded', style: TextStyle(color: AppColors.textGhost, fontSize: 12)),
              )
            else
              ...items.map((item) {
                final itm   = item as Map<String, dynamic>;
                final qty   = (itm['quantity'] as num? ?? 0).toDouble();
                final price = (itm['unitPrice'] as num? ?? 0).toDouble();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.success),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(itm['productName'] as String? ?? 'Product',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      if (itm['sku'] != null)
                        Text('SKU: ${itm['sku']}', style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)} units',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSec)),
                      Text('₹${(qty * price).toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
                    ]),
                  ]),
                );
              }),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.2)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total Value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('₹${_fmt.format(totalValue)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.success)),
              ]),
            ),
            const SizedBox(height: 80),
          ]),
        ),
      ),
    );
  }

  Widget _infoCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGhost))),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
    ]),
  );
}
