import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';

class DealDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const DealDetailScreen({super.key, required this.id});
  @override
  ConsumerState<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends ConsumerState<DealDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _deal;
  final _fmt = NumberFormat('#,##,###', 'en_IN');
  static const _purple = Color(0xFF8B5CF6);
  static const _stages = ['PROSPECT', 'QUALIFIED', 'PROPOSAL', 'NEGOTIATION', 'WON', 'LOST'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().getDealDetail(widget.id);
      final raw = res.data['data'];
      if (!mounted) return;
      setState(() => _deal = raw is Map ? Map<String, dynamic>.from(raw as Map) : null);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _cs() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Coming soon'), behavior: SnackBarBehavior.floating));

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

  Future<void> _updateStage(String newStage) async {
    try {
      await ApiClient().updateDeal(widget.id, {'stage': newStage});
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Stage updated to $newStage'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to update stage'),
        backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: _purple)));
    if (_deal == null) return Scaffold(
      appBar: AppBar(title: const Text('Deal Detail')),
      body: const Center(child: Text('Deal not found', style: TextStyle(color: AppColors.textGhost))),
    );

    final d = _deal!;
    final stage = d['stage'] as String? ?? 'PROSPECT';
    final stageColor = _stageColor(stage);
    final value = (d['value'] as num? ?? d['amount'] as num? ?? 0).toDouble();
    final title = d['title'] as String? ?? d['name'] as String? ?? 'Deal';

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await context.push<bool>('/deals/edit', extra: d);
              if (result == true) _load();
            },
          ),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: _cs),
        ],
      ),
      body: RefreshIndicator(
        color: _purple,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [stageColor, stageColor.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.handshake_outlined, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                    child: Text(stage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 12),
                Text('₹${_fmt.format(value)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 4),
                if ((d['party']?['name'] as String? ?? d['partyName'] as String? ?? '').isNotEmpty)
                  Text(d['party']?['name'] as String? ?? d['partyName'] as String? ?? '',
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 16),
            const Text('Move Stage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _stages.map((s) {
                  final isCurrent = s == stage;
                  final c = _stageColor(s);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: isCurrent ? null : () => _updateStage(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isCurrent ? c : c.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.withOpacity(0.4)),
                        ),
                        child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isCurrent ? Colors.white : c)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _infoCard([
              _row('Value',       '₹${_fmt.format(value)}'),
              _row('Stage',       stage),
              _row('Owner',       d['owner']?['name'] as String? ?? d['ownerName'] as String? ?? '—'),
              _row('Close Date',  d['closeDate'] as String? ?? d['expectedClose'] as String? ?? '—'),
              _row('Probability', '${d['probability'] ?? '—'}%'),
              _row('Source',      d['source'] as String? ?? '—'),
              if ((d['description'] as String? ?? '').isNotEmpty)
                _row('Description', d['description'] as String),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _actBtn('Log Activity', Icons.timeline_outlined, AppColors.primary, _cs)),
              const SizedBox(width: 10),
              Expanded(child: _actBtn('Send Quote', Icons.request_quote_outlined, AppColors.info, _cs)),
              const SizedBox(width: 10),
              Expanded(child: _actBtn('Link Invoice', Icons.receipt_long_outlined, AppColors.warning, _cs)),
            ]),
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

  Widget _actBtn(String label, IconData icon, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
      ]),
    ),
  );
}
