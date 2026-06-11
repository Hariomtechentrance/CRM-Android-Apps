import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/shimmer_list.dart';

class DealsScreen extends ConsumerStatefulWidget {
  const DealsScreen({super.key});
  @override
  ConsumerState<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends ConsumerState<DealsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  List<dynamic> _deals = [];
  String _stageFilter = 'ALL';
  final _fmt = NumberFormat('#,##,###', 'en_IN');

  static const _purple = Color(0xFF8B5CF6);
  static const _stages = ['ALL', 'PROSPECT', 'QUALIFIED', 'PROPOSAL', 'NEGOTIATION', 'WON', 'LOST'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().getDeals();
      final raw = res.data['data'];
      if (!mounted) return;
      setState(() => _deals = raw is List ? raw : (raw?['deals'] as List? ?? []));
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Color _stageColor(String? s) {
    switch (s) {
      case 'WON':         return AppColors.success;
      case 'LOST':        return AppColors.danger;
      case 'QUALIFIED':   return AppColors.info;
      case 'PROPOSAL':    return AppColors.primary;
      case 'NEGOTIATION': return AppColors.warning;
      default:            return AppColors.textGhost;
    }
  }

  List<dynamic> get _filtered => _stageFilter == 'ALL'
      ? _deals
      : _deals.where((d) => (d as Map<String, dynamic>)['stage'] == _stageFilter).toList();

  double get _totalPipeline => _deals
      .where((d) => (d as Map<String, dynamic>)['stage'] != 'LOST')
      .fold(0, (s, d) => s + ((d['value'] as num? ?? 0).toDouble()));

  double get _totalWon => _deals
      .where((d) => (d as Map<String, dynamic>)['stage'] == 'WON')
      .fold(0, (s, d) => s + ((d['value'] as num? ?? 0).toDouble()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Deals'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await context.push<bool>('/deals/add');
              if (result == true) _load();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: _purple,
          unselectedLabelColor: AppColors.textGhost,
          indicatorColor: _purple,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Pipeline'), Tab(text: 'All Deals')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _loading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : _buildPipeline(),
        _loading
            ? const ShimmerList(itemHeight: 72)
            : _buildList(),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push<bool>('/deals/add');
          if (result == true) _load();
        },
        backgroundColor: _purple,
        icon: const Icon(Icons.handshake_outlined, color: Colors.white),
        label: const Text('New Deal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildPipeline() => RefreshIndicator(
    color: _purple,
    onRefresh: _load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: _PipeCard(label: 'Pipeline', value: '₹${_fmt.format(_totalPipeline)}', icon: Icons.account_tree_outlined, color: _purple)),
        const SizedBox(width: 10),
        Expanded(child: _PipeCard(label: 'Won', value: '₹${_fmt.format(_totalWon)}', icon: Icons.emoji_events_outlined, color: AppColors.success)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _PipeCard(
          label: 'Open',
          value: '${_deals.where((d) => (d as Map<String, dynamic>)['stage'] != 'WON' && d['stage'] != 'LOST').length}',
          icon: Icons.pending_outlined, color: AppColors.warning)),
        const SizedBox(width: 10),
        Expanded(child: _PipeCard(
          label: 'Won Count',
          value: '${_deals.where((d) => (d as Map<String, dynamic>)['stage'] == 'WON').length}',
          icon: Icons.check_circle_outline, color: AppColors.info)),
      ]),
      const SizedBox(height: 20),
      const Text('By Stage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      ...['PROSPECT', 'QUALIFIED', 'PROPOSAL', 'NEGOTIATION', 'WON', 'LOST'].map((stage) {
        final stageDeals = _deals.where((d) => (d as Map<String, dynamic>)['stage'] == stage).toList();
        if (stageDeals.isEmpty) return const SizedBox.shrink();
        final c = _stageColor(stage);
        final stageValue = stageDeals.fold<double>(0, (s, d) => s + ((d['value'] as num? ?? 0).toDouble()));
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.circle, size: 10, color: c),
              ),
              title: Text(stage, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
              subtitle: Text('${stageDeals.length} deals  •  ₹${_fmt.format(stageValue)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
              children: stageDeals.map((d) => _DealTile(
                deal: d as Map<String, dynamic>,
                stageColor: _stageColor,
              )).toList(),
            ),
          ),
        );
      }),
    ]),
  );

  Widget _buildList() => Column(children: [
    SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: _stages.map((s) {
          final sel = _stageFilter == s;
          final c = s == 'ALL' ? _purple : _stageColor(s);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : c)),
              selected: sel,
              onSelected: (_) => setState(() => _stageFilter = s),
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
              icon: Icons.handshake_outlined,
              message: 'No deals found',
              subtitle: 'Add your first deal to track pipeline',
              actionLabel: 'Add Deal',
              onAction: () async {
                final result = await context.push<bool>('/deals/add');
                if (result == true) _load();
              },
            )
          : RefreshIndicator(
              color: _purple,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _DealTile(deal: _filtered[i] as Map<String, dynamic>, stageColor: _stageColor),
              ),
            ),
    ),
  ]);
}

class _DealTile extends StatelessWidget {
  final Map<String, dynamic> deal;
  final Color Function(String?) stageColor;
  const _DealTile({required this.deal, required this.stageColor});

  @override
  Widget build(BuildContext context) {
    final stage = deal['stage'] as String? ?? 'PROSPECT';
    final color = stageColor(stage);
    final title = deal['title'] as String? ?? deal['name'] as String? ?? 'Untitled Deal';
    final party = deal['party']?['name'] as String? ?? deal['partyName'] as String? ?? '';
    final value = (deal['value'] as num? ?? deal['amount'] as num? ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => context.push('/deals/${deal['id']}'),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.handshake_outlined, size: 18, color: color),
        ),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        subtitle: Text(party.isNotEmpty ? party : stage, style: const TextStyle(fontSize: 12, color: AppColors.textGhost)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(stage, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
      ),
    );
  }
}

class _PipeCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _PipeCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGhost, fontWeight: FontWeight.w500)),
    ]),
  );
}
