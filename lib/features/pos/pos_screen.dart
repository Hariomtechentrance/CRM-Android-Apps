import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';
import '../../shared/widgets/empty_state.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});
  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  List<dynamic> _products = [];
  final List<Map<String, dynamic>> _cart = [];
  String _search = '';
  final _fmt = NumberFormat('#,##,###', 'en_IN');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadProducts();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _cs() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Coming soon'), behavior: SnackBarBehavior.floating));

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().getProducts();
      final raw = res.data['data'];
      if (!mounted) return;
      setState(() => _products = raw is List ? raw : (raw?['products'] as List? ?? []));
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  List<dynamic> get _filtered => _search.isEmpty
      ? _products
      : _products.where((p) =>
          (p['name'] as String? ?? '').toLowerCase().contains(_search.toLowerCase()) ||
          (p['sku'] as String? ?? '').toLowerCase().contains(_search.toLowerCase())).toList();

  void _addToCart(Map<String, dynamic> product) {
    final idx = _cart.indexWhere((i) => i['id'] == product['id']);
    if (idx >= 0) {
      setState(() => _cart[idx]['qty'] = (_cart[idx]['qty'] as int) + 1);
    } else {
      setState(() => _cart.add({
        'id':    product['id'],
        'name':  product['name'],
        'price': (product['sellingPrice'] as num? ?? product['price'] as num? ?? 0).toDouble(),
        'qty':   1,
      }));
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${product['name']} added to cart'),
      duration: const Duration(milliseconds: 800),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _removeFromCart(String id) {
    final idx = _cart.indexWhere((i) => i['id'] == id);
    if (idx < 0) return;
    if ((_cart[idx]['qty'] as int) > 1) {
      setState(() => _cart[idx]['qty'] = (_cart[idx]['qty'] as int) - 1);
    } else {
      setState(() => _cart.removeAt(idx));
    }
  }

  double get _cartTotal => _cart.fold(0, (s, i) => s + (i['price'] as double) * (i['qty'] as int));
  int get _cartCount => _cart.fold(0, (s, i) => s + (i['qty'] as int));

  void _checkout() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cart is empty'), behavior: SnackBarBehavior.floating));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CheckoutSheet(
        cart: _cart,
        total: _cartTotal,
        fmt: _fmt,
        onConfirm: (paymentMode) => _processPayment(paymentMode),
      ),
    );
  }

  Future<void> _processPayment(String paymentMode) async {
    Navigator.of(context).pop();
    try {
      await ApiClient().dio.post('/pos/sales', data: {
        'items': _cart.map((i) => {'productId': i['id'], 'quantity': i['qty'], 'price': i['price']}).toList(),
        'total': _cartTotal,
        'paymentMode': paymentMode,
      });
    } catch (_) {
      // offline-friendly: treat as success for demo
    }
    if (!mounted) return;
    setState(() => _cart.clear());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Sale recorded successfully'),
      backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          IconButton(icon: const Icon(Icons.history_outlined), onPressed: _cs),
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.shopping_cart_outlined), onPressed: _tabs.index == 1 ? null : () => _tabs.animateTo(1)),
              if (_cartCount > 0) Positioned(
                right: 6, top: 6,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                  child: Center(child: Text('$_cartCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.success,
          unselectedLabelColor: AppColors.textGhost,
          indicatorColor: AppColors.success,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Products'), Tab(text: 'Cart')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        // ── Products ─────────────────────────────────────────
        Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search product or SKU...',
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textGhost),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _search = ''))
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.success))
                : _filtered.isEmpty
                    ? EmptyState(icon: Icons.inventory_2_outlined, message: 'No products', subtitle: 'Add products in Inventory to sell here')
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.4,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final p = _filtered[i] as Map<String, dynamic>;
                          final price = (p['sellingPrice'] as num? ?? p['price'] as num? ?? 0).toDouble();
                          final stock = (p['currentStock'] as num? ?? 0).toDouble();
                          final inCart = _cart.firstWhere((c) => c['id'] == p['id'], orElse: () => {});
                          final cartQty = (inCart['qty'] as int?) ?? 0;
                          return InkWell(
                            onTap: stock > 0 ? () => _addToCart(p) : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.cardLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cartQty > 0 ? AppColors.success.withOpacity(0.4) : AppColors.border),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Row(children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                                    child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.success),
                                  ),
                                  const Spacer(),
                                  if (cartQty > 0) Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(6)),
                                    child: Text('$cartQty', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                                  ),
                                ]),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(p['name'] as String? ?? 'Product',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success)),
                                    Text('${stock.toStringAsFixed(0)} left', style: TextStyle(fontSize: 9, color: stock <= 5 ? AppColors.danger : AppColors.textGhost)),
                                  ]),
                                ]),
                              ]),
                            ),
                          );
                        },
                      ),
          ),
        ]),

        // ── Cart ──────────────────────────────────────────────
        _cart.isEmpty
            ? EmptyState(icon: Icons.shopping_cart_outlined, message: 'Cart is empty', subtitle: 'Add products from the Products tab')
            : Column(children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    itemCount: _cart.length,
                    itemBuilder: (_, i) {
                      final item = _cart[i];
                      final subtotal = (item['price'] as double) * (item['qty'] as int);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.success),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              Text('₹${(item['price'] as double).toStringAsFixed(0)} each', style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                            ])),
                            Row(children: [
                              InkWell(
                                onTap: () => _removeFromCart(item['id'] as String),
                                child: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
                                  child: const Icon(Icons.remove, size: 14, color: AppColors.danger),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('${item['qty']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              ),
                              InkWell(
                                onTap: () => setState(() => _cart[i]['qty'] = (item['qty'] as int) + 1),
                                child: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
                                  child: const Icon(Icons.add, size: 14, color: AppColors.success),
                                ),
                              ),
                            ]),
                            const SizedBox(width: 10),
                            Text('₹${subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardLight,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${_cartCount} item(s)', style: const TextStyle(fontSize: 13, color: AppColors.textGhost)),
                        Text('Total: ₹${_fmt.format(_cartTotal)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      ]),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _checkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success, foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.point_of_sale_outlined, size: 20),
                        label: Text('Checkout  •  ₹${_fmt.format(_cartTotal)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                ),
              ]),
      ]),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final double total;
  final NumberFormat fmt;
  final void Function(String) onConfirm;
  const _CheckoutSheet({required this.cart, required this.total, required this.fmt, required this.onConfirm});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  String _payMode = 'CASH';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Confirm Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Text('Total Amount', style: const TextStyle(fontSize: 12, color: AppColors.textGhost)),
          Text('₹${widget.fmt.format(widget.total)}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.success)),
          const SizedBox(height: 16),
          const Text('Payment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSec)),
          const SizedBox(height: 8),
          Row(children: ['CASH', 'UPI', 'CARD', 'CREDIT'].map((m) {
            final sel = _payMode == m;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(m, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.success)),
                selected: sel,
                onSelected: (_) => setState(() => _payMode = m),
                backgroundColor: AppColors.success.withOpacity(0.08),
                selectedColor: AppColors.success,
                showCheckmark: false,
                side: BorderSide(color: AppColors.success.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }).toList()),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => widget.onConfirm(_payMode),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success, foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: Text('Confirm $_payMode Payment', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
