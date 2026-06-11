import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';

class StockMarketScreen extends ConsumerStatefulWidget {
  const StockMarketScreen({super.key});
  @override
  ConsumerState<StockMarketScreen> createState() => _StockMarketScreenState();
}

class _StockMarketScreenState extends ConsumerState<StockMarketScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _calls = [], _research = [];
  bool _loadingC = true, _loadingR = true;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _loadCalls(); _loadResearch(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadCalls() async {
    setState(() => _loadingC = true);
    try {
      final res = await ApiClient().dio.get('/stock-market/calls', queryParameters: {'limit': 50});
      final d = res.data['data'];
      setState(() { _calls = (d is List ? d : d['calls'] ?? []) as List; _loadingC = false; });
    } catch (_) { setState(() => _loadingC = false); }
  }

  Future<void> _loadResearch() async {
    setState(() => _loadingR = true);
    try {
      final res = await ApiClient().dio.get('/stock-market/research', queryParameters: {'limit': 50});
      final d = res.data['data'];
      setState(() { _research = (d is List ? d : d['reports'] ?? d['research'] ?? []) as List; _loadingR = false; });
    } catch (_) { setState(() => _loadingR = false); }
  }

  Color _callColor(String? t) => t == 'BUY' ? AppColors.success : t == 'SELL' ? AppColors.danger : AppColors.textGhost;
  Color _statusColor(String? s) {
    switch (s?.toUpperCase()) {
      case 'OPEN': return AppColors.info;
      case 'TARGET_HIT': return AppColors.success;
      case 'SL_HIT': return AppColors.danger;
      default: return AppColors.textGhost;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLight,
    appBar: AppBar(title: const Text('Stock Market Advisory'), backgroundColor: Colors.white, foregroundColor: AppColors.textPrimary, elevation: 0,
      bottom: TabBar(controller: _tabs, labelColor: AppColors.primary, unselectedLabelColor: AppColors.textSec, indicatorColor: AppColors.primary,
        tabs: const [Tab(text: 'Trade Calls'), Tab(text: 'Research')])),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create trade calls on the web app for full analysis tools'))),
      backgroundColor: AppColors.danger,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('New Call', style: TextStyle(color: Colors.white)),
    ),
    body: TabBarView(controller: _tabs, children: [
      _loadingC ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(onRefresh: _loadCalls,
            child: _calls.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.candlestick_chart_outlined, size: 48, color: AppColors.textGhost),
                    SizedBox(height: 12), Text('No trade calls', style: TextStyle(color: AppColors.textSec))]))
                : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _calls.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final c = _calls[i];
                      final type = c['type'] as String? ?? c['callType'] as String? ?? 'BUY';
                      final status = c['status'] as String? ?? 'OPEN';
                      return Container(padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(c['symbol'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _callColor(type).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text(type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _callColor(type)))),
                            const Spacer(),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                              child: Text(status.replaceAll('_', ' '), style: TextStyle(fontSize: 10, color: _statusColor(status)))),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            _stat('Entry', '₹${c['entryPrice'] ?? '-'}'),
                            const SizedBox(width: 16),
                            _stat('Target', '₹${c['targetPrice'] ?? c['target'] ?? '-'}'),
                            const SizedBox(width: 16),
                            _stat('SL', '₹${c['stopLoss'] ?? c['sl'] ?? '-'}'),
                          ]),
                        ]));
                    })),
      _loadingR ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(onRefresh: _loadResearch,
            child: _research.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.analytics_outlined, size: 48, color: AppColors.textGhost),
                    SizedBox(height: 12), Text('No research reports', style: TextStyle(color: AppColors.textSec))]))
                : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _research.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final r = _research[i];
                      return Container(padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r['title'] ?? r['symbol'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('${r['recommendation'] ?? '-'}  •  ${r['analyst'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppColors.textSec)),
                        ]));
                    })),
    ]),
  );

  Widget _stat(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGhost)),
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
  ]);
}
