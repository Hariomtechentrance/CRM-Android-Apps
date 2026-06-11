import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';
import '../../shared/widgets/empty_state.dart';

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});
  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  List<dynamic> _shipments = [];
  final _fmt = NumberFormat('#,##,###', 'en_IN');

  static const _teal = Color(0xFF10B981);

  static final _demoShipments = [
    {'id': 's1', 'number': 'SHP-001', 'type': 'EXPORT', 'party': 'Global Trading Co.',   'value': 850000,  'status': 'IN_TRANSIT',  'port': 'JNPT Mumbai',   'eta': '2026-06-18'},
    {'id': 's2', 'number': 'SHP-002', 'type': 'IMPORT', 'party': 'China Goods Ltd.',     'value': 1250000, 'status': 'CUSTOMS',      'port': 'Chennai Port',  'eta': '2026-06-12'},
    {'id': 's3', 'number': 'SHP-003', 'type': 'EXPORT', 'party': 'UK Buyers Pvt Ltd',    'value': 420000,  'status': 'DELIVERED',    'port': 'Mundra Port',   'eta': '2026-06-05'},
    {'id': 's4', 'number': 'SHP-004', 'type': 'IMPORT', 'party': 'Dubai Suppliers FZE',  'value': 980000,  'status': 'BOOKING',      'port': 'JNPT Mumbai',   'eta': '2026-06-25'},
    {'id': 's5', 'number': 'SHP-005', 'type': 'EXPORT', 'party': 'Singapore Traders',    'value': 650000,  'status': 'LOADING',      'port': 'Kolkata Port',  'eta': '2026-06-22'},
  ];

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
      final res = await ApiClient().dio.get('/import-export/shipments');
      final raw = res.data['data'];
      if (!mounted) return;
      setState(() => _shipments = raw is List ? raw : (raw?['shipments'] as List? ?? []));
    } catch (_) {
      if (!mounted) return;
      setState(() => _shipments = List<Map<String, dynamic>>.from(_demoShipments));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'DELIVERED':  return AppColors.success;
      case 'IN_TRANSIT': return AppColors.primary;
      case 'CUSTOMS':    return AppColors.warning;
      case 'LOADING':    return AppColors.info;
      case 'BOOKING':    return AppColors.textGhost;
      case 'DELAYED':    return AppColors.danger;
      default:           return AppColors.textSec;
    }
  }

  Color _typeColor(String? t) => t == 'EXPORT' ? AppColors.success : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Import / Export'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.add), onPressed: _cs),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: _teal,
          unselectedLabelColor: AppColors.textGhost,
          indicatorColor: _teal,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Shipments'), Tab(text: 'Documents'), Tab(text: 'Summary')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        // ── Shipments ─────────────────────────────────────────
        _loading
            ? const Center(child: CircularProgressIndicator(color: _teal))
            : _buildShipments(),

        // ── Documents ─────────────────────────────────────────
        _buildDocs(),

        // ── Summary ───────────────────────────────────────────
        _buildSummary(),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _cs,
        backgroundColor: _teal,
        icon: const Icon(Icons.directions_boat_outlined, color: Colors.white),
        label: const Text('New Shipment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildShipments() {
    final exports = _shipments.where((s) => (s as Map<String, dynamic>)['type'] == 'EXPORT').toList();
    final imports = _shipments.where((s) => (s as Map<String, dynamic>)['type'] == 'IMPORT').toList();
    final totalExport = exports.fold<double>(0, (s, e) => s + ((e['value'] as num? ?? 0).toDouble()));
    final totalImport = imports.fold<double>(0, (s, e) => s + ((e['value'] as num? ?? 0).toDouble()));

    return RefreshIndicator(
      color: _teal,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: _StatCard(label: 'Export Value', value: '₹${_fmt.format(totalExport)}', icon: Icons.flight_takeoff, color: AppColors.success)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(label: 'Import Value', value: '₹${_fmt.format(totalImport)}', icon: Icons.flight_land, color: AppColors.primary)),
        ]),
        const SizedBox(height: 20),
        const Text('Active Shipments', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ..._shipments.map((s) {
          final shp = s as Map<String, dynamic>;
          final status = shp['status'] as String? ?? '';
          final type   = shp['type'] as String? ?? '';
          final sc = _statusColor(status);
          final tc = _typeColor(type);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: tc.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(type == 'EXPORT' ? Icons.flight_takeoff : Icons.flight_land, size: 18, color: tc),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(shp['number'] as String? ?? '#', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(shp['party'] as String? ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₹${_fmt.format(shp['value'] ?? 0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sc)),
                    ),
                  ]),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 12, color: AppColors.textGhost),
                  const SizedBox(width: 4),
                  Text(shp['port'] as String? ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                  const Spacer(),
                  Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textGhost),
                  const SizedBox(width: 4),
                  Text('ETA: ${shp['eta'] ?? '—'}', style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                ]),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  Widget _buildDocs() {
    final docTypes = [
      {'name': 'Bill of Lading',       'icon': Icons.description_outlined,     'count': 8,  'color': 0xFF6366F1},
      {'name': 'Invoice & Packing',    'icon': Icons.receipt_long_outlined,     'count': 12, 'color': 0xFF10B981},
      {'name': 'Certificate of Origin','icon': Icons.verified_outlined,         'count': 5,  'color': 0xFFF59E0B},
      {'name': 'Customs Declaration',  'icon': Icons.account_balance_outlined,  'count': 7,  'color': 0xFFEF4444},
      {'name': 'Insurance',            'icon': Icons.shield_outlined,            'count': 3,  'color': 0xFF8B5CF6},
      {'name': 'L/C Documents',        'icon': Icons.credit_card_outlined,      'count': 4,  'color': 0xFF06B6D4},
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docTypes.length,
      itemBuilder: (_, i) {
        final dt = docTypes[i];
        final c = Color(dt['color'] as int);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            onTap: _cs,
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(dt['icon'] as IconData, size: 20, color: c),
            ),
            title: Text(dt['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('${dt['count']} docs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textGhost),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildSummary() => ListView(padding: const EdgeInsets.all(16), children: [
    _SumCard('Total Exports', '₹${_fmt.format(8500000)}', Icons.flight_takeoff, AppColors.success),
    const SizedBox(height: 10),
    _SumCard('Total Imports', '₹${_fmt.format(6200000)}', Icons.flight_land, AppColors.primary),
    const SizedBox(height: 10),
    _SumCard('Active Shipments', '${_shipments.where((s) => (s as Map<String, dynamic>)['status'] != 'DELIVERED').length}', Icons.directions_boat_outlined, AppColors.info),
    const SizedBox(height: 10),
    _SumCard('Pending Customs', '${_shipments.where((s) => (s as Map<String, dynamic>)['status'] == 'CUSTOMS').length}', Icons.account_balance_outlined, AppColors.warning),
  ]);
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
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGhost)),
    ]),
  );
}

class _SumCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SumCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 20, color: color)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSec))),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}
