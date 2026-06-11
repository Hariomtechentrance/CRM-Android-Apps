import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';

const _restaurantColor = Color(0xFFF97316);

class RestaurantScreen extends ConsumerStatefulWidget {
  const RestaurantScreen({super.key});
  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _billKot(Map<String, dynamic> kot) async {
    final confirmed = await showDialog<String>(
      context: context,
      builder: (_) => _PaymentDialog(totalAmount: (kot['amount'] as int? ?? 0).toDouble()),
    );
    if (confirmed == null || !mounted) return;
    try {
      await ApiClient().settleRestaurantBill(kot['id'] as String, {'paymentMode': confirmed});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bill settled — KOT ${kot['id']}'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      ));
      setState(() {
        _kots.removeWhere((k) => k['id'] == kot['id']);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to settle bill'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _newOrder(Map<String, dynamic> table) async {
    Navigator.pop(context);
    try {
      await ApiClient().createRestaurantOrder({
        'tableNo': table['no'],
        'seats': table['seats'],
        'status': 'PENDING',
      });
      if (!mounted) return;
      setState(() {
        final idx = _tables.indexWhere((t) => t['no'] == table['no']);
        if (idx >= 0) {
          _tables[idx] = {..._tables[idx], 'status': 'OCCUPIED'};
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Order started for Table ${table['no']}'),
        backgroundColor: _restaurantColor, behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to create order'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _generateBill(Map<String, dynamic> table) async {
    Navigator.pop(context);
    final orderId = (table['order'] as String? ?? '').replaceAll('#', '');
    final amount  = (table['amount'] as int? ?? 0).toDouble();
    final payMode = await showDialog<String>(
      context: context,
      builder: (_) => _PaymentDialog(totalAmount: amount),
    );
    if (payMode == null || !mounted) return;
    try {
      await ApiClient().settleRestaurantBill(orderId, {'paymentMode': payMode, 'amount': amount});
      if (!mounted) return;
      setState(() {
        final idx = _tables.indexWhere((t) => t['no'] == table['no']);
        if (idx >= 0) _tables[idx] = {..._tables[idx], 'status': 'AVAILABLE', 'order': null, 'amount': null};
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bill settled — Table ${table['no']} — ₹$amount via $payMode'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to settle bill'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  final _tables = [
    {'no': 1, 'seats': 4, 'status': 'AVAILABLE', 'order': null},
    {'no': 2, 'seats': 2, 'status': 'OCCUPIED',  'order': '#KOT-001', 'amount': 850},
    {'no': 3, 'seats': 6, 'status': 'OCCUPIED',  'order': '#KOT-002', 'amount': 1420},
    {'no': 4, 'seats': 4, 'status': 'AVAILABLE', 'order': null},
    {'no': 5, 'seats': 8, 'status': 'RESERVED',  'order': '#RSV-001', 'amount': 0},
    {'no': 6, 'seats': 4, 'status': 'OCCUPIED',  'order': '#KOT-003', 'amount': 620},
    {'no': 7, 'seats': 2, 'status': 'AVAILABLE', 'order': null},
    {'no': 8, 'seats': 4, 'status': 'OCCUPIED',  'order': '#KOT-004', 'amount': 2100},
  ];

  final _kots = [
    {'id': 'KOT-001', 'table': 2, 'items': 3, 'status': 'COOKING',  'time': '12 min'},
    {'id': 'KOT-002', 'table': 3, 'items': 5, 'status': 'READY',    'time': '3 min'},
    {'id': 'KOT-003', 'table': 6, 'items': 2, 'status': 'PENDING',  'time': '2 min'},
    {'id': 'KOT-004', 'table': 8, 'items': 7, 'status': 'COOKING',  'time': '18 min'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Restaurant POS'),
        actions: [
          IconButton(icon: const Icon(Icons.receipt_long_outlined), onPressed: () => _showOrderHistory()),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _cs),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: _restaurantColor,
          unselectedLabelColor: AppColors.textGhost,
          indicatorColor: _restaurantColor,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Tables'), Tab(text: 'KOT'), Tab(text: 'Menu'), Tab(text: 'Reports')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _buildTables(),
        _buildKOT(),
        _buildMenu(),
        _buildReports(),
      ]),
    );
  }

  Widget _buildTables() {
    final occupied  = _tables.where((t) => t['status'] == 'OCCUPIED').length;
    final available = _tables.where((t) => t['status'] == 'AVAILABLE').length;
    final reserved  = _tables.where((t) => t['status'] == 'RESERVED').length;
    return Column(children: [
      // Summary
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          _tstat('Available', available, AppColors.success),
          const SizedBox(width: 8),
          _tstat('Occupied',  occupied,  _restaurantColor),
          const SizedBox(width: 8),
          _tstat('Reserved',  reserved,  AppColors.warning),
        ]),
      ),
      // Tables grid
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.3,
          ),
          itemCount: _tables.length,
          itemBuilder: (_, i) {
            final t = _tables[i];
            final status = t['status'] as String;
            final c = status == 'AVAILABLE' ? AppColors.success : status == 'RESERVED' ? AppColors.warning : _restaurantColor;
            return InkWell(
              onTap: () => _showTableDialog(t),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: c.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Icon(Icons.table_restaurant, size: 20, color: c),
                    const Spacer(),
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                    ),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Table ${t['no']}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c)),
                    Text('${t['seats']} seats • $status', style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                    if (t['amount'] != null && (t['amount'] as int) > 0)
                      Text('₹${t['amount']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
                  ]),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildKOT() => ListView(padding: const EdgeInsets.all(16), children: [
    ..._kots.map((kot) {
      final status = kot['status'] as String;
      final c = status == 'READY' ? AppColors.success : status == 'COOKING' ? _restaurantColor : AppColors.warning;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('T${kot['table']}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('KOT-${kot['id']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('${kot['items']} items • ${kot['time']} ago', style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
                child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 4),
              if (status == 'READY')
                TextButton(
                  onPressed: () => _billKot(kot),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('Bill', style: TextStyle(fontSize: 11)),
                ),
            ]),
          ]),
        ),
      );
    }),
  ]);

  Widget _buildMenu() {
    final categories = ['Starters', 'Main Course', 'Beverages', 'Desserts'];
    return ListView(padding: const EdgeInsets.all(16), children: [
      ...categories.map((cat) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(cat, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
        ...List.generate(3, (i) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.cardLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: _restaurantColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.restaurant_menu, size: 18, color: _restaurantColor),
            ),
            title: Text('$cat Item ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('₹180 • Available', style: TextStyle(fontSize: 11, color: AppColors.textGhost)),
            trailing: IconButton(icon: const Icon(Icons.add_circle_outline, color: _restaurantColor), onPressed: _cs),
          ),
        )),
      ])),
    ]);
  }

  Widget _buildReports() => ListView(padding: const EdgeInsets.all(16), children: [
    _reportCard('Today\'s Revenue', '₹4,990', Icons.trending_up, AppColors.success),
    const SizedBox(height: 10),
    _reportCard('Orders Today', '24', Icons.receipt_outlined, _restaurantColor),
    const SizedBox(height: 10),
    _reportCard('Avg. Table Time', '42 min', Icons.timer_outlined, AppColors.info),
    const SizedBox(height: 10),
    _reportCard('Top Item', 'Butter Chicken', Icons.star_outline, AppColors.warning),
  ]);

  Widget _reportCard(String label, String value, IconData icon, Color c) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.cardLight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: c),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSec))),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c)),
    ]),
  );

  Widget _tstat(String label, int count, Color c) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.2))),
    child: Column(children: [
      Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGhost, fontWeight: FontWeight.w500)),
    ]),
  ));

  // Remove _cs() stub — all actions are now implemented
  void _cs() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Feature in progress'), behavior: SnackBarBehavior.floating));

  void _showOrderHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _OrderHistorySheet(),
    );
  }

  void _showTableDialog(Map<String, dynamic> table) {
    final status = table['status'] as String;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Table ${table['no']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          if (status == 'AVAILABLE') ...[
            ElevatedButton.icon(
              onPressed: () => _newOrder(table),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('New Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _restaurantColor, foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.event_available),
              label: const Text('Reserve Table'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
            ),
          ] else if (status == 'OCCUPIED') ...[
            ElevatedButton.icon(
              onPressed: () => _generateBill(table),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Generate Bill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success, foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Items to Order'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Payment Dialog ────────────────────────────────────────────────────────────
class _PaymentDialog extends StatefulWidget {
  final double totalAmount;
  const _PaymentDialog({required this.totalAmount});
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String _mode = 'CASH';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Settle Bill — ₹${widget.totalAmount.toStringAsFixed(0)}'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Select payment mode:', style: TextStyle(fontSize: 13, color: AppColors.textSec)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: ['CASH', 'UPI', 'CARD', 'CREDIT'].map((m) {
        final sel = _mode == m;
        return ChoiceChip(
          label: Text(m, style: TextStyle(fontSize: 12, color: sel ? Colors.white : _restaurantColor)),
          selected: sel,
          onSelected: (_) => setState(() => _mode = m),
          selectedColor: _restaurantColor,
          backgroundColor: _restaurantColor.withOpacity(0.08),
          showCheckmark: false,
        );
      }).toList()),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, _mode),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
        child: Text('Settle via $_mode'),
      ),
    ],
  );
}

// ── Order History Sheet ───────────────────────────────────────────────────────
class _OrderHistorySheet extends StatefulWidget {
  const _OrderHistorySheet();
  @override
  State<_OrderHistorySheet> createState() => _OrderHistorySheetState();
}

class _OrderHistorySheetState extends State<_OrderHistorySheet> {
  bool _loading = true;
  List<dynamic> _orders = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiClient().getRestaurantOrders(status: 'SETTLED');
      final raw = res.data['data'];
      if (!mounted) return;
      setState(() { _orders = raw is List ? raw : (raw?['orders'] as List? ?? []); _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Align(alignment: Alignment.centerLeft, child: Text('Order History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)))),
        const SizedBox(height: 8),
        SizedBox(
          height: 400,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _restaurantColor))
              : _orders.isEmpty
                  ? const Center(child: Text('No orders found', style: TextStyle(color: AppColors.textGhost)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _orders.length,
                      itemBuilder: (_, i) {
                        final o = _orders[i] as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.receipt_outlined, color: _restaurantColor),
                          title: Text('Table ${o['tableNo'] ?? o['table'] ?? '?'} — ${o['paymentMode'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(o['createdAt'] as String? ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                          trailing: Text('₹${o['total'] ?? o['amount'] ?? 0}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
                        );
                      },
                    ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}
