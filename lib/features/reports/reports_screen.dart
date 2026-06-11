import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  DateTime _from = DateTime.now().subtract(const Duration(days: 180));
  DateTime _to   = DateTime.now();
  Map<String, dynamic> _salesKpi     = {};
  Map<String, dynamic> _financeKpi   = {};
  Map<String, dynamic> _crmKpi       = {};
  Map<String, dynamic> _inventoryKpi = {};
  bool _loadingKpi = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadKpis();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadKpis() async {
    setState(() => _loadingKpi = true);
    final fromStr = DateFormat('yyyy-MM-dd').format(_from);
    final toStr   = DateFormat('yyyy-MM-dd').format(_to);
    try {
      final results = await Future.wait([
        ApiClient().getSalesReport(from: fromStr, to: toStr),
        ApiClient().getFinanceReport(from: fromStr, to: toStr),
        ApiClient().getCrmReport(from: fromStr, to: toStr),
        ApiClient().getInventoryReport(from: fromStr, to: toStr),
      ]);
      if (!mounted) return;
      setState(() {
        _salesKpi     = results[0].data['data'] as Map<String, dynamic>? ?? {};
        _financeKpi   = results[1].data['data'] as Map<String, dynamic>? ?? {};
        _crmKpi       = results[2].data['data'] as Map<String, dynamic>? ?? {};
        _inventoryKpi = results[3].data['data'] as Map<String, dynamic>? ?? {};
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loadingKpi = false);
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.info)),
        child: child!,
      ),
    );
    if (range == null || !mounted) return;
    setState(() { _from = range.start; _to = range.end; });
    _loadKpis();
  }

  void _exportReport() {
    final fmt = NumberFormat('#,##,###', 'en_IN');
    final fromStr = DateFormat('dd MMM yyyy').format(_from);
    final toStr   = DateFormat('dd MMM yyyy').format(_to);
    final buffer = StringBuffer();
    buffer.writeln('FlowCRM Reports — $fromStr to $toStr');
    buffer.writeln('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}');
    buffer.writeln();
    buffer.writeln('SALES SUMMARY');
    buffer.writeln('Total Revenue,${_salesKpi['totalRevenue'] ?? '51.2L'}');
    buffer.writeln('Total Orders,${_salesKpi['totalOrders'] ?? '215'}');
    buffer.writeln('Average Order,${_salesKpi['avgOrderValue'] ?? '23.8K'}');
    buffer.writeln();
    buffer.writeln('FINANCE SUMMARY');
    buffer.writeln('Revenue,${_financeKpi['revenue'] ?? '51.2L'}');
    buffer.writeln('Expenses,${_financeKpi['expenses'] ?? '16.3L'}');
    buffer.writeln('Net Profit,${_financeKpi['netProfit'] ?? '34.9L'}');
    buffer.writeln();
    buffer.writeln('CRM SUMMARY');
    buffer.writeln('Total Leads,${_crmKpi['totalLeads'] ?? '142'}');
    buffer.writeln('Conversion Rate,${_crmKpi['conversionRate'] ?? '12.7%'}');
    buffer.writeln('Pipeline Value,${_crmKpi['pipelineValue'] ?? '8.4L'}');
    buffer.writeln();
    buffer.writeln('INVENTORY SUMMARY');
    buffer.writeln('Stock In,${_inventoryKpi['stockIn'] ?? '762'}');
    buffer.writeln('Stock Out,${_inventoryKpi['stockOut'] ?? '580'}');

    Share.share(buffer.toString(), subject: 'FlowCRM Reports $fromStr – $toStr');
  }

  String _fmtKpi(Map<String, dynamic> data, String key, String fallback) {
    final v = data[key];
    if (v == null) return fallback;
    if (v is num) return '₹${NumberFormat('#,##,###', 'en_IN').format(v.toInt())}';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final fromStr = DateFormat('dd MMM').format(_from);
    final toStr   = DateFormat('dd MMM yy').format(_to);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('Reports & Analytics'),
          Text('$fromStr – $toStr', style: const TextStyle(fontSize: 11, color: AppColors.textGhost, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.download_outlined), onPressed: _exportReport, tooltip: 'Export CSV'),
          IconButton(icon: const Icon(Icons.calendar_today_outlined), onPressed: _selectDateRange, tooltip: 'Date Range'),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppColors.info,
          unselectedLabelColor: AppColors.textGhost,
          indicatorColor: AppColors.info,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Sales'), Tab(text: 'Finance'), Tab(text: 'CRM'), Tab(text: 'Inventory')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _buildSalesReport(),
        _buildFinanceReport(),
        _buildCrmReport(),
        _buildInventoryReport(),
      ]),
    );
  }

  Widget _buildSalesReport() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Revenue Trend – Last 6 Months', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    const SizedBox(height: 12),
    _chartCard(LineChart(LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: const [FlSpot(0,2.4), FlSpot(1,3.1), FlSpot(2,2.8), FlSpot(3,4.2), FlSpot(4,3.9), FlSpot(5,5.1)],
          isCurved: true,
          color: AppColors.warning,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppColors.warning.withOpacity(0.08)),
        ),
      ],
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) => Text(
            ['Jan','Feb','Mar','Apr','May','Jun'][v.toInt()],
            style: const TextStyle(fontSize: 10, color: AppColors.textGhost),
          ),
        )),
      ),
      gridData: FlGridData(show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
    ))),
    const SizedBox(height: 20),
    const Text('Monthly Orders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    const SizedBox(height: 12),
    _chartCard(BarChart(BarChartData(
      barGroups: List.generate(6, (i) => BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: [24, 31, 28, 42, 39, 51][i].toDouble(),
          color: AppColors.primary,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ])),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) => Text(
            ['J','F','M','A','M','J'][v.toInt()],
            style: const TextStyle(fontSize: 10, color: AppColors.textGhost),
          ),
        )),
      ),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
    ))),
    const SizedBox(height: 20),
    _kpiRow([
      _kpi('Total Revenue', _fmtKpi(_salesKpi, 'totalRevenue', '₹51.2L'), AppColors.warning),
      _kpi('Orders',        _salesKpi['totalOrders']?.toString() ?? '215',  AppColors.primary),
      _kpi('Avg. Order',    _fmtKpi(_salesKpi, 'avgOrderValue', '₹23.8K'), AppColors.success),
    ]),
  ]);

  Widget _buildFinanceReport() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('P&L Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    const SizedBox(height: 12),
    _chartCard(PieChart(PieChartData(
      sections: [
        PieChartSectionData(value: 68, color: AppColors.success,   title: 'Revenue\n68%', radius: 80, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
        PieChartSectionData(value: 22, color: AppColors.warning,   title: 'COGS\n22%',    radius: 80, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
        PieChartSectionData(value: 10, color: AppColors.danger,    title: 'Opex\n10%',    radius: 80, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
      sectionsSpace: 2,
      centerSpaceRadius: 40,
    ))),
    const SizedBox(height: 20),
    _kpiRow([
      _kpi('Revenue',    _fmtKpi(_financeKpi, 'revenue',   '₹51.2L'), AppColors.success),
      _kpi('Expenses',   _fmtKpi(_financeKpi, 'expenses',  '₹16.3L'), AppColors.danger),
      _kpi('Net Profit', _fmtKpi(_financeKpi, 'netProfit', '₹34.9L'), AppColors.primary),
    ]),
  ]);

  Widget _buildCrmReport() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Lead Funnel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    const SizedBox(height: 12),
    _chartCard(BarChart(BarChartData(
      barGroups: [
        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 142, color: AppColors.info,      width: 28, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 89,  color: AppColors.primary,   width: 28, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 54,  color: AppColors.warning,   width: 28, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
        BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 31,  color: AppColors.secondary, width: 28, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
        BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 18,  color: AppColors.success,   width: 28, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))]),
      ],
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) => Text(
            ['New','Contact','Qualify','Proposal','Won'][v.toInt()],
            style: const TextStyle(fontSize: 9, color: AppColors.textGhost),
          ),
        )),
      ),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
    ))),
    const SizedBox(height: 20),
    _kpiRow([
      _kpi('Total Leads',   _crmKpi['totalLeads']?.toString() ?? '142',                AppColors.info),
      _kpi('Conversion',    _crmKpi['conversionRate']?.toString() ?? '12.7%',          AppColors.success),
      _kpi('Pipeline Val.', _fmtKpi(_crmKpi, 'pipelineValue', '₹8.4L'),               AppColors.warning),
    ]),
  ]);

  Widget _buildInventoryReport() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Stock Movement Trend', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    const SizedBox(height: 12),
    _chartCard(LineChart(LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: const [FlSpot(0,120), FlSpot(1,95), FlSpot(2,140), FlSpot(3,88), FlSpot(4,162), FlSpot(5,135)],
          isCurved: true, color: AppColors.success, barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppColors.success.withOpacity(0.08)),
        ),
        LineChartBarData(
          spots: const [FlSpot(0,80), FlSpot(1,110), FlSpot(2,75), FlSpot(3,120), FlSpot(4,90), FlSpot(5,105)],
          isCurved: true, color: AppColors.danger, barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppColors.danger.withOpacity(0.05)),
        ),
      ],
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) => Text(
            ['Jan','Feb','Mar','Apr','May','Jun'][v.toInt()],
            style: const TextStyle(fontSize: 10, color: AppColors.textGhost),
          ),
        )),
      ),
      gridData: FlGridData(show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
    ))),
    const SizedBox(height: 8),
    Row(children: [
      _legend('Stock In', AppColors.success),
      const SizedBox(width: 16),
      _legend('Stock Out', AppColors.danger),
    ]),
    const SizedBox(height: 20),
    _kpiRow([
      _kpi('Stock In',  _inventoryKpi['stockIn']?.toString()  ?? '762',  AppColors.success),
      _kpi('Stock Out', _inventoryKpi['stockOut']?.toString() ?? '580',  AppColors.danger),
      _kpi('Low Stock', _inventoryKpi['lowStock']?.toString() ?? '12',   AppColors.warning),
    ]),
  ]);

  Widget _chartCard(Widget chart) => Container(
    height: 220, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: chart,
  );

  Widget _kpiRow(List<Widget> items) => Row(
    children: items.map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: w))).toList(),
  );

  Widget _kpi(String label, String value, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.2))),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textGhost, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
    ]),
  );

  Widget _legend(String label, Color c) => Row(children: [
    Container(width: 12, height: 3, color: c),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
  ]);
}
