import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';

class RetailScreen extends ConsumerStatefulWidget {
  const RetailScreen({super.key});
  @override
  ConsumerState<RetailScreen> createState() => _RetailScreenState();
}

class _RetailScreenState extends ConsumerState<RetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _products = [], _orders = [];
  bool _loadingP = true, _loadingO = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadProducts();
    _loadOrders();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadProducts() async {
    setState(() => _loadingP = true);
    try {
      final res = await ApiClient().getProducts(page: 1);
      final raw = res.data['data'];
      setState(() { _products = (raw is List ? raw : raw['products'] ?? []) as List; _loadingP = false; });
    } catch (_) { setState(() => _loadingP = false); }
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingO = true);
    try {
      final res = await ApiClient().getSalesOrders(page: 1);
      final raw = res.data['data'];
      setState(() { _orders = (raw is List ? raw : raw['salesOrders'] ?? raw['orders'] ?? []) as List; _loadingO = false; });
    } catch (_) { setState(() => _loadingO = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLight,
    appBar: AppBar(
      title: const Text('Retail & Fashion'),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      bottom: TabBar(controller: _tabs,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSec,
        indicatorColor: AppColors.primary,
        tabs: const [Tab(text: 'Products'), Tab(text: 'Sales Orders')]),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.push('/inventory/edit'),
      backgroundColor: const Color(0xFF8B5CF6),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('Add Product', style: TextStyle(color: Colors.white)),
    ),
    body: TabBarView(controller: _tabs, children: [
      // Products
      _loadingP ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(onRefresh: _loadProducts,
              child: _products.isEmpty
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.checkroom_outlined, size: 48, color: AppColors.textGhost),
                      SizedBox(height: 12), Text('No products', style: TextStyle(color: AppColors.textSec))]))
                  : ListView.separated(padding: const EdgeInsets.all(16),
                      itemCount: _products.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final p = _products[i];
                        return Container(padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                          child: Row(children: [
                            Container(width: 42, height: 42,
                              decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.checkroom_outlined, color: Color(0xFF8B5CF6), size: 20)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                              Text('SKU: ${p['sku'] ?? '-'}  •  Stock: ${p['stockQuantity'] ?? 0}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSec)),
                            ])),
                            Text('₹${p['sellingPrice'] ?? p['price'] ?? 0}',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ]));
                      })),
      // Sales Orders
      _loadingO ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(onRefresh: _loadOrders,
              child: _orders.isEmpty
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long, size: 48, color: AppColors.textGhost),
                      SizedBox(height: 12), Text('No orders', style: TextStyle(color: AppColors.textSec))]))
                  : ListView.separated(padding: const EdgeInsets.all(16),
                      itemCount: _orders.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final o = _orders[i];
                        return Container(padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                          child: Row(children: [
                            const Icon(Icons.local_shipping_outlined, color: AppColors.warning, size: 24),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(o['orderNumber'] ?? o['soNumber'] ?? '-',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                              Text(o['partyName'] ?? o['party']?['name'] ?? '-',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSec)),
                            ])),
                            Text('₹${o['totalAmount'] ?? o['total'] ?? 0}',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ]));
                      })),
    ]),
  );
}
