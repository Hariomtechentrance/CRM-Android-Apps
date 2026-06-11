import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});
  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _catalog = [], _amc = [];
  bool _loadingC = true, _loadingA = true;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _loadCatalog(); _loadAmc(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadCatalog() async {
    setState(() => _loadingC = true);
    try {
      final res = await ApiClient().dio.get('/services/catalog', queryParameters: {'limit': 50});
      final d = res.data['data'];
      setState(() { _catalog = (d is List ? d : d['services'] ?? d['catalog'] ?? []) as List; _loadingC = false; });
    } catch (_) { setState(() => _loadingC = false); }
  }

  Future<void> _loadAmc() async {
    setState(() => _loadingA = true);
    try {
      final res = await ApiClient().dio.get('/services/amc', queryParameters: {'limit': 50});
      final d = res.data['data'];
      setState(() { _amc = (d is List ? d : d['contracts'] ?? d['amc'] ?? []) as List; _loadingA = false; });
    } catch (_) { setState(() => _loadingA = false); }
  }

  Color _amcColor(String? s) {
    switch (s?.toUpperCase()) {
      case 'ACTIVE':  return AppColors.success;
      case 'EXPIRED': return AppColors.danger;
      default:        return AppColors.warning;
    }
  }

  void _showAddService() {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Add Service', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Service Name *')),
          const SizedBox(height: 12),
          TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate (₹)')),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                await ApiClient().dio.post('/services/catalog', data: {'name': nameCtrl.text.trim(), 'rate': double.tryParse(rateCtrl.text) ?? 0});
                if (ctx.mounted) Navigator.pop(ctx);
                _loadCatalog();
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Save Service', style: TextStyle(color: Colors.white)),
          ),
        ]),
      ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLight,
    appBar: AppBar(title: const Text('Services'), backgroundColor: Colors.white, foregroundColor: AppColors.textPrimary, elevation: 0,
      bottom: TabBar(controller: _tabs, labelColor: AppColors.primary, unselectedLabelColor: AppColors.textSec, indicatorColor: AppColors.primary,
        tabs: const [Tab(text: 'Service Catalog'), Tab(text: 'AMC Contracts')])),
    floatingActionButton: FloatingActionButton(onPressed: _showAddService, backgroundColor: AppColors.primary,
      child: const Icon(Icons.add, color: Colors.white)),
    body: TabBarView(controller: _tabs, children: [
      _loadingC ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(onRefresh: _loadCatalog,
            child: _catalog.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.miscellaneous_services_outlined, size: 48, color: AppColors.textGhost),
                    SizedBox(height: 12), Text('No services yet', style: TextStyle(color: AppColors.textSec))]))
                : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _catalog.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final s = _catalog[i];
                      return Container(padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.miscellaneous_services_outlined, color: AppColors.warning, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                            Text(s['category'] ?? 'General', style: const TextStyle(fontSize: 11, color: AppColors.textSec)),
                          ])),
                          Text('₹${s['rate'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ]));
                    })),
      _loadingA ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(onRefresh: _loadAmc,
            child: _amc.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.handshake_outlined, size: 48, color: AppColors.textGhost),
                    SizedBox(height: 12), Text('No AMC contracts', style: TextStyle(color: AppColors.textSec))]))
                : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _amc.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final c = _amc[i];
                      final status = c['status'] as String? ?? 'PENDING';
                      return Container(padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['contractNo'] ?? c['name'] ?? 'AMC-${i + 1}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                            Text(c['clientName'] ?? c['party']?['name'] ?? '-', style: const TextStyle(fontSize: 12, color: AppColors.textSec)),
                            Text('₹${c['value'] ?? 0}', style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                          ])),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _amcColor(status).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _amcColor(status)))),
                        ]));
                    })),
    ]),
  );
}
