import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/shimmer_list.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});
  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  List<dynamic> _entries = [];
  List<dynamic> _pending = [];
  Map<String, dynamic> _summary = {};
  String _statusFilter = 'ALL';
  final _fmt = NumberFormat('#,##,###', 'en_IN');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _cs() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coming soon'), behavior: SnackBarBehavior.floating));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get('/store/goods-entries');
      final raw = res.data['data'];
      if (!mounted) return;
      final list = raw is List ? raw : (raw?['entries'] as List? ?? []);
      setState(() {
        _entries = list;
        _pending = list.where((e) => (e as Map<String, dynamic>)['status'] == 'PENDING').toList();
        final total = list.fold<double>(0, (s, e) => s + ((e['totalValue'] as num? ?? 0).toDouble()));
        _summary = {'totalEntries': list.length, 'totalValue': total};
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'RECEIVED':  return AppColors.success;
      case 'PENDING':   return AppColors.warning;
      case 'REJECTED':  return AppColors.danger;
      case 'PARTIAL':   return AppColors.info;
      default:          return AppColors.textGhost;
    }
  }

  List<dynamic> get _filtered => _statusFilter == 'ALL'
      ? _entries
      : _entries.where((e) => (e as Map<String, dynamic>)['status'] == _statusFilter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Store (Inward)'),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner_outlined, size: 22), onPressed: _cs),
          IconButton(
            icon: const Icon(Icons.add_box_outlined, size: 22),
            onPressed: () async {
              final result = await context.push<bool>('/store/add');
              if (result == true) _load();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.success,
          unselectedLabelColor: AppColors.textGhost,
          indicatorColor: AppColors.success,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Entries'), Tab(text: 'Pending')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.success))
            : _buildOverview(),
        _loading
            ? const ShimmerList(itemHeight: 72)
            : _buildEntries(),
        _loading
            ? const ShimmerList(itemHeight: 72)
            : _pending.isEmpty
                ? EmptyState(icon: Icons.inbox_outlined, message: 'No pending entries', subtitle: 'All goods have been received')
                : RefreshIndicator(
                    color: AppColors.warning,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: _pending.length,
                      itemBuilder: (_, i) => _EntryTile(entry: _pending[i] as Map<String, dynamic>, statusColor: _statusColor),
                    ),
                  ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push<bool>('/store/add');
          if (result == true) _load();
        },
        backgroundColor: AppColors.success,
        icon: const Icon(Icons.move_to_inbox_outlined, color: Colors.white),
        label: const Text('New Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildOverview() => RefreshIndicator(
    color: AppColors.success,
    onRefresh: _load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: _StatCard(label: 'Total Entries', value: '${_summary['totalEntries'] ?? _entries.length}', icon: Icons.inventory_outlined, color: AppColors.success)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Total Value', value: '₹${_fmt.format(_summary['totalValue'] ?? 0)}', icon: Icons.currency_rupee, color: AppColors.primary)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _StatCard(label: 'Pending', value: '${_entries.where((e) => (e as Map<String, dynamic>)['status'] == 'PENDING').length}', icon: Icons.pending_outlined, color: AppColors.warning)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Received', value: '${_entries.where((e) => (e as Map<String, dynamic>)['status'] == 'RECEIVED').length}', icon: Icons.check_circle_outline, color: AppColors.info)),
      ]),
      const SizedBox(height: 20),
      const Text('Quick Actions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _ActionBtn(label: 'New GRN', icon: Icons.add_box_outlined, color: AppColors.success, onTap: () async {
          final result = await context.push<bool>('/store/add');
          if (result == true) _load();
        })),
        const SizedBox(width: 10),
        Expanded(child: _ActionBtn(label: 'Reports', icon: Icons.bar_chart_outlined, color: AppColors.info, onTap: _cs)),
        const SizedBox(width: 10),
        Expanded(child: _ActionBtn(label: 'Scan QR', icon: Icons.qr_code_scanner_outlined, color: AppColors.secondary, onTap: _cs)),
      ]),
      const SizedBox(height: 20),
      const Text('Recent Entries', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      if (_entries.isEmpty)
        EmptyState(icon: Icons.move_to_inbox_outlined, message: 'No goods entries yet', subtitle: 'Create your first goods receipt note')
      else
        ..._entries.take(5).map((e) => _EntryTile(entry: e as Map<String, dynamic>, statusColor: _statusColor)),
    ]),
  );

  Widget _buildEntries() => Column(children: [
    SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: ['ALL', 'PENDING', 'RECEIVED', 'PARTIAL', 'REJECTED'].map((s) {
          final sel = _statusFilter == s;
          final c = s == 'ALL' ? AppColors.success : _statusColor(s);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : c)),
              selected: sel,
              onSelected: (_) => setState(() => _statusFilter = s),
              backgroundColor: c.withOpacity(0.08),
              selectedColor: c,
              showCheckmark: false,
              side: BorderSide(color: c.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }).toList(),
      ),
    ),
    Expanded(
      child: _filtered.isEmpty
          ? EmptyState(
              icon: Icons.move_to_inbox_outlined,
              message: 'No entries found',
              subtitle: 'Add your first goods receipt note',
              actionLabel: 'Add GRN',
              onAction: () async {
                final result = await context.push<bool>('/store/add');
                if (result == true) _load();
              },
            )
          : RefreshIndicator(
              color: AppColors.success,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _EntryTile(entry: _filtered[i] as Map<String, dynamic>, statusColor: _statusColor),
              ),
            ),
    ),
  ]);
}

class _EntryTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final Color Function(String?) statusColor;
  const _EntryTile({required this.entry, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final status = entry['status'] as String? ?? 'PENDING';
    final color = statusColor(status);
    final grn = entry['grnNumber'] as String? ?? '#';
    final supplier = entry['supplierName'] as String? ?? entry['supplier']?['name'] as String? ?? 'Unknown Supplier';
    final value = (entry['totalValue'] as num? ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => context.push('/store/${entry['id']}'),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.move_to_inbox_outlined, size: 18, color: color),
        ),
        title: Text(grn, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Text(supplier, style: const TextStyle(fontSize: 12, color: AppColors.textGhost)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGhost, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}
