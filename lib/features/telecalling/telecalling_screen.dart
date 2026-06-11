import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/shimmer_list.dart';

class TelecallingScreen extends ConsumerStatefulWidget {
  const TelecallingScreen({super.key});
  @override
  ConsumerState<TelecallingScreen> createState() => _TelecallingScreenState();
}

class _TelecallingScreenState extends ConsumerState<TelecallingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  List<dynamic> _calls = [];
  List<dynamic> _campaigns = [];

  static const _green = Color(0xFF10B981);

  static final _demoCalls = [
    {'id': 'c1', 'party': 'Raj Traders',      'phone': '+91 98765 43210', 'type': 'OUTBOUND', 'status': 'CONNECTED', 'duration': '4:32', 'outcome': 'INTERESTED',  'date': '2026-06-10'},
    {'id': 'c2', 'party': 'Mehra Plastics',   'phone': '+91 87654 32109', 'type': 'OUTBOUND', 'status': 'NO_ANSWER', 'duration': '—',    'outcome': 'CALLBACK',    'date': '2026-06-10'},
    {'id': 'c3', 'party': 'XYZ Corporation',  'phone': '+91 76543 21098', 'type': 'INBOUND',  'status': 'CONNECTED', 'duration': '2:18', 'outcome': 'FOLLOW_UP',   'date': '2026-06-09'},
    {'id': 'c4', 'party': 'Patel Industries', 'phone': '+91 65432 10987', 'type': 'OUTBOUND', 'status': 'CONNECTED', 'duration': '6:45', 'outcome': 'DEAL_CLOSED', 'date': '2026-06-09'},
    {'id': 'c5', 'party': 'Global Imports',   'phone': '+91 54321 09876', 'type': 'OUTBOUND', 'status': 'BUSY',      'duration': '—',    'outcome': 'RETRY',       'date': '2026-06-08'},
  ];

  static final _demoCampaigns = [
    {'id': 'cp1', 'name': 'June Export Drive',   'total': 150, 'done': 87, 'status': 'ACTIVE',    'assigned': 'Team A'},
    {'id': 'cp2', 'name': 'Q2 Product Launch',   'total': 80,  'done': 80, 'status': 'COMPLETED', 'assigned': 'Team B'},
    {'id': 'cp3', 'name': 'Overdue Collections', 'total': 42,  'done': 18, 'status': 'ACTIVE',    'assigned': 'Team A'},
    {'id': 'cp4', 'name': 'New Lead Nurture',     'total': 200, 'done': 0,  'status': 'PENDING',   'assigned': 'Team C'},
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().getTelecallingCalls();
      final raw = res.data['data'];
      if (!mounted) return;
      setState(() => _calls = raw is List ? raw : (raw?['calls'] as List? ?? []));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _calls     = List<Map<String, dynamic>>.from(_demoCalls);
        _campaigns = List<Map<String, dynamic>>.from(_demoCampaigns);
      });
    }
    try {
      final res = await ApiClient().getTelecallingCampaigns();
      final raw = res.data['data'];
      if (!mounted) return;
      setState(() => _campaigns = raw is List ? raw : (raw?['campaigns'] as List? ?? []));
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _exportCalls() {
    if (_calls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No call logs to export'), behavior: SnackBarBehavior.floating));
      return;
    }
    final buf = StringBuffer('Party,Phone,Type,Status,Outcome,Duration,Date\n');
    for (final c in _calls.cast<Map<String, dynamic>>()) {
      buf.writeln('${c['party']},${c['phone']},${c['type']},${c['status']},${c['outcome']},${c['duration']},${c['date']}');
    }
    Share.share(buf.toString(), subject: 'Telecalling Logs Export');
  }

  void _showLogCallSheet() {
    final partyCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String type    = 'OUTBOUND';
    String status  = 'CONNECTED';
    String outcome = 'INTERESTED';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Log Call', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(controller: partyCtrl, decoration: const InputDecoration(labelText: 'Party Name *')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: ['OUTBOUND', 'INBOUND'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setS(() => type = v!),
              )),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['CONNECTED', 'NO_ANSWER', 'BUSY', 'VOICEMAIL'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setS(() => status = v!),
              )),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: outcome,
              decoration: const InputDecoration(labelText: 'Outcome'),
              items: ['INTERESTED', 'FOLLOW_UP', 'DEAL_CLOSED', 'CALLBACK', 'NOT_INTERESTED', 'RETRY']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setS(() => outcome = v!),
            ),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (partyCtrl.text.trim().isEmpty) return;
                try {
                  await ApiClient().logTelecallingCall({
                    'party': partyCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'type': type,
                    'status': status,
                    'outcome': outcome,
                    'notes': notesCtrl.text.trim(),
                    'date': DateTime.now().toIso8601String(),
                  });
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Save Call Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  void _showCreateCampaignSheet() {
    final nameCtrl   = TextEditingController();
    final totalCtrl  = TextEditingController();
    String assigned  = 'Team A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('New Campaign', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Campaign Name *')),
            const SizedBox(height: 10),
            TextField(controller: totalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Calls Target')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: assigned,
              decoration: const InputDecoration(labelText: 'Assign To'),
              items: ['Team A', 'Team B', 'Team C'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setS(() => assigned = v!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                try {
                  await ApiClient().createTelecallingCampaign({
                    'name': nameCtrl.text.trim(),
                    'total': int.tryParse(totalCtrl.text) ?? 0,
                    'assigned': assigned,
                  });
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Create Campaign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  void _showCallDetail(Map<String, dynamic> call) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: (call['type'] == 'INBOUND' ? AppColors.primary : _green).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(call['type'] == 'INBOUND' ? Icons.call_received_outlined : Icons.call_made_outlined,
                  color: call['type'] == 'INBOUND' ? AppColors.primary : _green),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(call['party'] as String? ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Text(call['phone'] as String? ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textGhost)),
            ])),
          ]),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          _row('Type',     call['type']     as String? ?? ''),
          _row('Status',   call['status']   as String? ?? ''),
          _row('Outcome',  call['outcome']  as String? ?? ''),
          _row('Duration', call['duration'] as String? ?? '—'),
          _row('Date',     call['date']     as String? ?? ''),
          if ((call['notes'] as String? ?? '').isNotEmpty)
            _row('Notes', call['notes'] as String),
        ]),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGhost))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
    ]),
  );

  Color _outcomeColor(String? o) {
    switch (o) {
      case 'DEAL_CLOSED': return AppColors.success;
      case 'INTERESTED':  return AppColors.primary;
      case 'FOLLOW_UP':   return AppColors.info;
      case 'CALLBACK':    return AppColors.warning;
      case 'RETRY':       return AppColors.textGhost;
      default:            return AppColors.textSec;
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'CONNECTED': return AppColors.success;
      case 'NO_ANSWER': return AppColors.warning;
      case 'BUSY':      return AppColors.danger;
      default:          return AppColors.textGhost;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected  = _calls.where((c) => (c as Map<String, dynamic>)['status'] == 'CONNECTED').length;
    final noAnswer   = _calls.where((c) => (c as Map<String, dynamic>)['status'] == 'NO_ANSWER').length;
    final dealClosed = _calls.where((c) => (c as Map<String, dynamic>)['outcome'] == 'DEAL_CLOSED').length;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Tele-calling'),
        actions: [
          IconButton(icon: const Icon(Icons.download_outlined), onPressed: _exportCalls),
          IconButton(icon: const Icon(Icons.add), onPressed: _showLogCallSheet),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: _green,
          unselectedLabelColor: AppColors.textGhost,
          indicatorColor: _green,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Call Logs'), Tab(text: 'Campaigns'), Tab(text: 'Stats')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        // ── Call Logs ─────────────────────────────────────────
        _loading
            ? const ShimmerList(itemHeight: 72)
            : _calls.isEmpty
                ? EmptyState(
                    icon: Icons.phone_in_talk_outlined,
                    message: 'No call logs',
                    subtitle: 'Call logs will appear after calls are logged',
                    actionLabel: 'Log First Call',
                    onAction: _showLogCallSheet,
                  )
                : RefreshIndicator(
                    color: _green,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: _calls.length,
                      itemBuilder: (_, i) {
                        final call   = _calls[i] as Map<String, dynamic>;
                        final status  = call['status']  as String? ?? '';
                        final outcome = call['outcome'] as String? ?? '';
                        final type    = call['type']    as String? ?? 'OUTBOUND';
                        final sc = _statusColor(status);
                        final oc = _outcomeColor(outcome);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            onTap: () => _showCallDetail(call),
                            leading: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: (type == 'INBOUND' ? AppColors.primary : _green).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                type == 'INBOUND' ? Icons.call_received_outlined : Icons.call_made_outlined,
                                size: 18,
                                color: type == 'INBOUND' ? AppColors.primary : _green,
                              ),
                            ),
                            title: Text(call['party'] as String? ?? 'Unknown',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            subtitle: Text('${call['phone']}  •  ${call['duration']}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sc)),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: oc.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text(outcome, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: oc)),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),

        // ── Campaigns ─────────────────────────────────────────
        _campaigns.isEmpty
            ? EmptyState(
                icon: Icons.campaign_outlined,
                message: 'No campaigns',
                subtitle: 'Create calling campaigns to manage bulk outreach',
                actionLabel: 'New Campaign',
                onAction: _showCreateCampaignSheet,
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: _campaigns.length,
                itemBuilder: (_, i) {
                  final cp    = _campaigns[i] as Map<String, dynamic>;
                  final total = (cp['total'] as int? ?? 1);
                  final done  = (cp['done'] as int? ?? 0);
                  final pct   = done / total;
                  final status = cp['status'] as String? ?? 'PENDING';
                  final sc = status == 'COMPLETED' ? AppColors.success : status == 'ACTIVE' ? _green : AppColors.textGhost;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(cp['name'] as String? ?? 'Campaign',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: _green.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(_green),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('$done / $total calls  •  ${(pct * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                        const Spacer(),
                        Text(cp['assigned'] as String? ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                      ]),
                    ]),
                  );
                },
              ),

        // ── Stats ─────────────────────────────────────────────
        ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(child: _StatPill(label: 'Total Calls', value: '${_calls.length}', color: _green)),
            const SizedBox(width: 8),
            Expanded(child: _StatPill(label: 'Connected', value: '$connected', color: AppColors.success)),
            const SizedBox(width: 8),
            Expanded(child: _StatPill(label: 'No Answer', value: '$noAnswer', color: AppColors.warning)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _StatPill(label: 'Deals Closed', value: '$dealClosed', color: AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(child: _StatPill(
              label: 'Connect Rate',
              value: _calls.isEmpty ? '0%' : '${((connected / _calls.length) * 100).toStringAsFixed(0)}%',
              color: AppColors.info,
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatPill(label: 'Campaigns', value: '${_campaigns.length}', color: AppColors.secondary)),
          ]),
        ]),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showLogCallSheet,
        backgroundColor: _green,
        icon: const Icon(Icons.phone_in_talk_outlined, color: Colors.white),
        label: const Text('Log Call', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textGhost, fontWeight: FontWeight.w500)),
    ]),
  );
}
