import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';

class GstScreen extends ConsumerStatefulWidget {
  const GstScreen({super.key});
  @override
  ConsumerState<GstScreen> createState() => _GstScreenState();
}

class _GstScreenState extends ConsumerState<GstScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  Map<String, dynamic> _summary = {};
  List<dynamic> _gstr1 = [];
  List<dynamic> _gstr3b = [];
  List<dynamic> _gstr2a = [];
  final _fmt = NumberFormat('#,##,###', 'en_IN');
  String _selectedPeriod = '';

  static final _demoGstr1 = [
    {'id': 'g1_1', 'period': 'May 2026',   'taxable': 850000,  'tax': 135000, 'status': 'FILED'},
    {'id': 'g1_2', 'period': 'April 2026', 'taxable': 720000,  'tax': 112000, 'status': 'FILED'},
    {'id': 'g1_3', 'period': 'March 2026', 'taxable': 940000,  'tax': 148000, 'status': 'PENDING'},
    {'id': 'g1_4', 'period': 'Feb 2026',   'taxable': 680000,  'tax': 98000,  'status': 'FILED'},
  ];
  static final _demoGstr3b = [
    {'id': 'g3_1', 'period': 'May 2026',   'tax': 135000, 'paid': 135000, 'status': 'FILED'},
    {'id': 'g3_2', 'period': 'April 2026', 'tax': 112000, 'paid': 112000, 'status': 'FILED'},
    {'id': 'g3_3', 'period': 'March 2026', 'tax': 148000, 'paid': 0,      'status': 'PENDING'},
  ];
  static final _demoGstr2a = [
    {'id': 'g2_1', 'period': 'May 2026',   'taxable': 320000, 'tax': 48000,  'status': 'AVAILABLE'},
    {'id': 'g2_2', 'period': 'April 2026', 'taxable': 280000, 'tax': 38000,  'status': 'AVAILABLE'},
    {'id': 'g2_3', 'period': 'March 2026', 'taxable': 410000, 'tax': 62000,  'status': 'AVAILABLE'},
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient().getGstReturns(type: 'GSTR1',  period: _selectedPeriod.isEmpty ? null : _selectedPeriod),
        ApiClient().getGstReturns(type: 'GSTR3B', period: _selectedPeriod.isEmpty ? null : _selectedPeriod),
        ApiClient().getGstReturns(type: 'GSTR2A', period: _selectedPeriod.isEmpty ? null : _selectedPeriod),
        ApiClient().dio.get('/gst/summary', queryParameters: {
          if (_selectedPeriod.isNotEmpty) 'period': _selectedPeriod,
        }),
      ]);
      if (!mounted) return;
      setState(() {
        final r1 = results[0].data['data'];
        _gstr1  = r1 is List ? r1 : (r1?['returns'] as List? ?? []);
        final r3 = results[1].data['data'];
        _gstr3b = r3 is List ? r3 : (r3?['returns'] as List? ?? []);
        final r2 = results[2].data['data'];
        _gstr2a = r2 is List ? r2 : (r2?['returns'] as List? ?? []);
        _summary = results[3].data['data'] as Map<String, dynamic>? ?? {};
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gstr1  = List<Map<String, dynamic>>.from(_demoGstr1);
        _gstr3b = List<Map<String, dynamic>>.from(_demoGstr3b);
        _gstr2a = List<Map<String, dynamic>>.from(_demoGstr2a);
      });
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _selectPeriod() async {
    final months = <String>[];
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      months.add(DateFormat('MMMM yyyy').format(d));
    }
    months.insert(0, 'All Periods');

    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select Period', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          const Divider(height: 1),
          ...months.map((m) => ListTile(
            title: Text(m, style: const TextStyle(fontSize: 14)),
            onTap: () => Navigator.of(context).pop(m),
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _selectedPeriod = result == 'All Periods' ? '' : result);
    _load();
  }

  void _downloadReport() {
    final buffer = StringBuffer();
    buffer.writeln('GST Report${_selectedPeriod.isNotEmpty ? " – $_selectedPeriod" : ""}');
    buffer.writeln('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}');
    buffer.writeln();
    buffer.writeln('GSTR-1 (Outward Supplies)');
    buffer.writeln('Period,Taxable Value,Tax,Status');
    for (final r in _gstr1) {
      final m = r as Map<String, dynamic>;
      buffer.writeln('${m['period']},${m['taxable'] ?? 0},${m['tax'] ?? 0},${m['status'] ?? ''}');
    }
    buffer.writeln();
    buffer.writeln('GSTR-3B (Monthly Return)');
    buffer.writeln('Period,Tax Liability,Paid,Status');
    for (final r in _gstr3b) {
      final m = r as Map<String, dynamic>;
      buffer.writeln('${m['period']},${m['tax'] ?? 0},${m['paid'] ?? 0},${m['status'] ?? ''}');
    }
    buffer.writeln();
    buffer.writeln('Summary');
    buffer.writeln('Taxable Value,CGST,SGST,IGST,Net Payable');
    buffer.writeln('${_summary['taxableValue'] ?? 0},${_summary['cgst'] ?? 0},${_summary['sgst'] ?? 0},${_summary['igst'] ?? 0},${_summary['netPayable'] ?? 0}');

    Share.share(buffer.toString(), subject: 'GST Report');
  }

  Future<void> _fileReturn(String returnType, Map<String, dynamic> item) async {
    final period = item['period'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('File $returnType'),
        content: Text('Are you sure you want to file $returnType for $period?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('File Now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiClient().fileGstReturn(returnType, period);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$returnType for $period filed successfully'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      ));
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Filing failed. Please try again.'),
        backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('GST Reports'),
          if (_selectedPeriod.isNotEmpty)
            Text(_selectedPeriod, style: const TextStyle(fontSize: 11, color: AppColors.textGhost, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.download_outlined), onPressed: _downloadReport, tooltip: 'Export CSV'),
          IconButton(icon: const Icon(Icons.calendar_today_outlined), onPressed: _selectPeriod, tooltip: 'Filter Period'),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppColors.success,
          unselectedLabelColor: AppColors.textGhost,
          indicatorColor: AppColors.success,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'GSTR-1'), Tab(text: 'GSTR-3B'), Tab(text: 'GSTR-2A'), Tab(text: 'Summary')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.success))
          : TabBarView(controller: _tabs, children: [
              _GstrTab(
                title: 'GSTR-1', subtitle: 'Outward Supplies (Sales)',
                items: _gstr1, fmt: _fmt,
                onFileTap: (item) => _fileReturn('GSTR1', item),
              ),
              _GstrTab(
                title: 'GSTR-3B', subtitle: 'Monthly Return Summary',
                items: _gstr3b, fmt: _fmt,
                onFileTap: (item) => _fileReturn('GSTR3B', item),
              ),
              _GstrTab(
                title: 'GSTR-2A', subtitle: 'Inward Supplies (Purchases)',
                items: _gstr2a, fmt: _fmt,
                showFileAction: false,
                onFileTap: (_) {},
              ),
              _buildSummary(),
            ]),
    );
  }

  Widget _buildSummary() => ListView(padding: const EdgeInsets.all(16), children: [
    _GstCard('Total Taxable Value', '₹${_fmt.format(_summary['taxableValue'] ?? 1250000)}', Icons.account_balance_outlined, AppColors.success),
    const SizedBox(height: 10),
    _GstCard('Total CGST',  '₹${_fmt.format(_summary['cgst']  ?? 56250)}', Icons.percent, AppColors.primary),
    const SizedBox(height: 10),
    _GstCard('Total SGST',  '₹${_fmt.format(_summary['sgst']  ?? 56250)}', Icons.percent, AppColors.info),
    const SizedBox(height: 10),
    _GstCard('Total IGST',  '₹${_fmt.format(_summary['igst']  ?? 22500)}', Icons.percent, AppColors.warning),
    const SizedBox(height: 10),
    _GstCard('Net Payable', '₹${_fmt.format(_summary['netPayable'] ?? 135000)}', Icons.payment_outlined, AppColors.danger),
  ]);
}

class _GstrTab extends StatelessWidget {
  final String title, subtitle;
  final List<dynamic> items;
  final NumberFormat fmt;
  final bool showFileAction;
  final void Function(Map<String, dynamic>) onFileTap;

  const _GstrTab({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.fmt,
    this.showFileAction = true,
    required this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      ),
      Expanded(
        child: items.isEmpty
            ? const Center(child: Text('No records found', style: TextStyle(color: AppColors.textGhost)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i] as Map<String, dynamic>;
                  final status = item['status'] as String? ?? '';
                  final isPending = status == 'PENDING';
                  final isFiled   = status == 'FILED' || status == 'AVAILABLE';
                  final color = isFiled ? AppColors.success : isPending ? AppColors.warning : AppColors.textGhost;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isPending ? AppColors.warning.withOpacity(0.3) : AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(isFiled ? Icons.check_circle_outline : Icons.schedule_outlined, size: 18, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item['period'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text('Taxable: ₹${fmt.format(item['taxable'] ?? 0)}', style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('₹${fmt.format(item['tax'] ?? 0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          if (isPending && showFileAction)
                            GestureDetector(
                              onTap: () => onFileTap(item),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(6)),
                                child: const Text('FILE NOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                            ),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

class _GstCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _GstCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.cardLight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSec))),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}
