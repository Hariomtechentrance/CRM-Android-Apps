import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';
import '../../shared/widgets/empty_state.dart';

class AutomationsScreen extends ConsumerStatefulWidget {
  const AutomationsScreen({super.key});
  @override
  ConsumerState<AutomationsScreen> createState() => _AutomationsScreenState();
}

class _AutomationsScreenState extends ConsumerState<AutomationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  List<dynamic> _automations = [];

  static const _purple = Color(0xFF8B5CF6);

  static final _demoAutomations = [
    {'id': '1', 'name': 'Lead → Welcome Email',     'trigger': 'NEW_LEAD',        'action': 'SEND_EMAIL',      'enabled': true,  'runCount': 142, 'category': 'CRM'},
    {'id': '2', 'name': 'Overdue Invoice Alert',     'trigger': 'INVOICE_OVERDUE', 'action': 'SEND_WHATSAPP',   'enabled': true,  'runCount': 38,  'category': 'Finance'},
    {'id': '3', 'name': 'Low Stock Notification',    'trigger': 'LOW_STOCK',       'action': 'NOTIFY_ADMIN',    'enabled': false, 'runCount': 15,  'category': 'Inventory'},
    {'id': '4', 'name': 'Deal Won → Create Invoice', 'trigger': 'DEAL_WON',        'action': 'CREATE_INVOICE',  'enabled': true,  'runCount': 27,  'category': 'Sales'},
    {'id': '5', 'name': 'New PO → Notify Store',     'trigger': 'NEW_PO',          'action': 'NOTIFY_TEAM',     'enabled': false, 'runCount': 64,  'category': 'Purchase'},
    {'id': '6', 'name': 'Ticket Unresolved 24h',     'trigger': 'TICKET_PENDING',  'action': 'ESCALATE',        'enabled': true,  'runCount': 9,   'category': 'Support'},
  ];

  static final _templates = [
    {'name': 'Lead Follow-up',    'desc': 'Auto-send email when lead is created',        'icon': Icons.email_outlined,             'color': 0xFF6366F1},
    {'name': 'Payment Reminder',  'desc': 'WhatsApp reminder on invoice due date',        'icon': Icons.payments_outlined,          'color': 0xFFEF4444},
    {'name': 'Stock Alert',       'desc': 'Notify when product falls below reorder level','icon': Icons.inventory_outlined,         'color': 0xFFF59E0B},
    {'name': 'Deal Stage Change', 'desc': 'Assign task when deal moves to Negotiation',   'icon': Icons.handshake_outlined,         'color': 0xFF8B5CF6},
    {'name': 'Birthday Wish',     'desc': 'Auto WhatsApp/Email on contact birthday',      'icon': Icons.cake_outlined,              'color': 0xFFEC4899},
    {'name': 'Ticket Escalation', 'desc': 'Escalate ticket if unresolved after 24 hours', 'icon': Icons.headset_mic_outlined,       'color': 0xFFEF4444},
    {'name': 'Welcome Message',   'desc': 'Send welcome message to new CRM party',        'icon': Icons.waving_hand_outlined,       'color': 0xFF10B981},
    {'name': 'PO Approval Alert', 'desc': 'Notify admin when PO requires approval',       'icon': Icons.approval_outlined,          'color': 0xFF06B6D4},
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateAutomationSheet(onCreated: _load),
    );
  }

  void _showLogsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _AutomationLogsSheet(),
    );
  }

  Future<void> _useTemplate(Map<String, dynamic> template) async {
    try {
      await ApiClient().createAutomationFromTemplate(template['name'] as String, {
        'name': template['name'],
        'desc': template['desc'],
      });
      if (!mounted) return;
      _load();
      _tabs.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${template['name']} automation added'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to add automation'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _deleteAutomation(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Automation'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiClient().deleteAutomation(id);
        _load();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Delete failed'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get('/automations');
      final raw = res.data['data'];
      if (!mounted) return;
      setState(() => _automations = raw is List ? raw : (raw?['automations'] as List? ?? []));
    } catch (_) {
      if (!mounted) return;
      setState(() => _automations = List<Map<String, dynamic>>.from(_demoAutomations));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _toggleAutomation(String id, bool enabled) async {
    try {
      await ApiClient().dio.patch('/automations/$id', data: {'enabled': enabled});
      _load();
    } catch (_) {
      setState(() {
        for (final a in _automations) {
          if ((a as Map<String, dynamic>)['id'] == id) a['enabled'] = enabled;
        }
      });
    }
  }

  IconData _triggerIcon(String? t) {
    switch (t) {
      case 'NEW_LEAD':        return Icons.person_add_outlined;
      case 'INVOICE_OVERDUE': return Icons.warning_outlined;
      case 'LOW_STOCK':       return Icons.inventory_outlined;
      case 'DEAL_WON':        return Icons.emoji_events_outlined;
      case 'NEW_PO':          return Icons.shopping_cart_outlined;
      case 'TICKET_PENDING':  return Icons.headset_mic_outlined;
      default:                return Icons.bolt_outlined;
    }
  }

  Color _catColor(String? cat) {
    switch (cat) {
      case 'CRM':       return AppColors.primary;
      case 'Finance':   return AppColors.danger;
      case 'Inventory': return AppColors.warning;
      case 'Sales':     return AppColors.success;
      case 'Purchase':  return AppColors.secondary;
      case 'Support':   return AppColors.info;
      default:          return _purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Automations'),
        actions: [
          IconButton(icon: const Icon(Icons.history_outlined), onPressed: _showLogsSheet),
          IconButton(icon: const Icon(Icons.add), onPressed: _showCreateDialog),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: _purple,
          unselectedLabelColor: AppColors.textGhost,
          indicatorColor: _purple,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Active'), Tab(text: 'Templates'), Tab(text: 'Logs')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _loading ? const Center(child: CircularProgressIndicator(color: _purple)) : _buildActive(),
        _buildTemplates(),
        const _AutomationLogsSheet(embedded: true),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: _purple,
        icon: const Icon(Icons.bolt_outlined, color: Colors.white),
        label: const Text('New Rule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildActive() {
    final active   = _automations.where((a) => (a as Map<String, dynamic>)['enabled'] == true).toList();
    final inactive = _automations.where((a) => (a as Map<String, dynamic>)['enabled'] != true).toList();
    final totalRuns = _automations.fold<int>(0, (s, a) => s + ((a as Map<String, dynamic>)['runCount'] as int? ?? 0));

    return RefreshIndicator(
      color: _purple,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 80), children: [
        Row(children: [
          Expanded(child: _StatPill(label: 'Total Rules', value: '${_automations.length}', color: _purple)),
          const SizedBox(width: 8),
          Expanded(child: _StatPill(label: 'Active', value: '${active.length}', color: AppColors.success)),
          const SizedBox(width: 8),
          Expanded(child: _StatPill(label: 'Total Runs', value: '$totalRuns', color: AppColors.info)),
        ]),
        const SizedBox(height: 20),
        if (active.isNotEmpty) ...[
          const Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textGhost, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          ...(active).map((a) => _AutoCard(
            automation: a as Map<String, dynamic>,
            onToggle: (v) => _toggleAutomation((a)['id'] as String, v),
            onDelete: () => _deleteAutomation((a)['id'] as String, (a)['name'] as String? ?? ''),
            triggerIcon: _triggerIcon,
            catColor: _catColor,
          )),
        ],
        if (inactive.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Inactive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textGhost, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          ...(inactive).map((a) => _AutoCard(
            automation: a as Map<String, dynamic>,
            onToggle: (v) => _toggleAutomation((a)['id'] as String, v),
            onDelete: () => _deleteAutomation((a)['id'] as String, (a)['name'] as String? ?? ''),
            triggerIcon: _triggerIcon,
            catColor: _catColor,
          )),
        ],
        if (_automations.isEmpty)
          EmptyState(icon: Icons.bolt_outlined, message: 'No automations yet', subtitle: 'Use templates to get started quickly'),
      ]),
    );
  }

  Widget _buildTemplates() => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
    itemCount: _templates.length,
    itemBuilder: (_, i) {
      final t = _templates[i];
      final c = Color(t['color'] as int);
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(t['icon'] as IconData, size: 20, color: c),
          ),
          title: Text(t['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          subtitle: Text(t['desc'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
          trailing: ElevatedButton(
            onPressed: () => _useTemplate(t),
            style: ElevatedButton.styleFrom(
              backgroundColor: c, foregroundColor: Colors.white,
              minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            child: const Text('Use'),
          ),
        ),
      );
    },
  );
}

class _AutoCard extends StatelessWidget {
  final Map<String, dynamic> automation;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final IconData Function(String?) triggerIcon;
  final Color Function(String?) catColor;
  const _AutoCard({required this.automation, required this.onToggle, required this.onDelete, required this.triggerIcon, required this.catColor});

  @override
  Widget build(BuildContext context) {
    final enabled = automation['enabled'] as bool? ?? false;
    final cat = automation['category'] as String? ?? '';
    final c = catColor(cat);
    return GestureDetector(
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: enabled ? c.withOpacity(0.3) : AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
              child: Icon(triggerIcon(automation['trigger'] as String?), size: 18, color: c),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(automation['name'] as String? ?? 'Automation',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                  child: Text(cat, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
                ),
                const SizedBox(width: 6),
                Text('${automation['runCount'] ?? 0} runs', style: const TextStyle(fontSize: 10, color: AppColors.textGhost)),
              ]),
            ])),
            Switch.adaptive(value: enabled, onChanged: onToggle, activeColor: const Color(0xFF8B5CF6)),
          ]),
        ),
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

// ── Create Automation Sheet ───────────────────────────────────────────────────
class _CreateAutomationSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateAutomationSheet({required this.onCreated});
  @override
  State<_CreateAutomationSheet> createState() => _CreateAutomationSheetState();
}

class _CreateAutomationSheetState extends State<_CreateAutomationSheet> {
  static const _purple = Color(0xFF8B5CF6);
  final _nameCtrl = TextEditingController();
  String _trigger = 'NEW_LEAD';
  String _action  = 'SEND_EMAIL';
  String _category = 'CRM';
  bool _loading = false;

  static const _triggers = ['NEW_LEAD', 'INVOICE_OVERDUE', 'LOW_STOCK', 'DEAL_WON', 'NEW_PO', 'TICKET_PENDING', 'PAYMENT_RECEIVED', 'PARTY_ADDED'];
  static const _actions  = ['SEND_EMAIL', 'SEND_WHATSAPP', 'NOTIFY_ADMIN', 'CREATE_INVOICE', 'NOTIFY_TEAM', 'ESCALATE', 'CREATE_TASK'];
  static const _categories = ['CRM', 'Finance', 'Inventory', 'Sales', 'Purchase', 'Support', 'HR'];

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Automation name is required'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiClient().createAutomation({
        'name':     _nameCtrl.text.trim(),
        'trigger':  _trigger,
        'action':   _action,
        'category': _category,
        'enabled':  true,
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Automation created successfully'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to create automation'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('New Automation Rule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Rule Name *',
              prefixIcon: Icon(Icons.bolt_outlined, size: 18, color: AppColors.textGhost),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _trigger,
            decoration: const InputDecoration(labelText: 'When (Trigger)'),
            items: _triggers.map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' '), style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _trigger = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _action,
            decoration: const InputDecoration(labelText: 'Then (Action)'),
            items: _actions.map((a) => DropdownMenuItem(value: a, child: Text(a.replaceAll('_', ' '), style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _action = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple, foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.bolt_outlined),
            label: const Text('Create Rule', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ── Automation Logs ───────────────────────────────────────────────────────────
class _AutomationLogsSheet extends StatefulWidget {
  final bool embedded;
  const _AutomationLogsSheet({this.embedded = false});
  @override
  State<_AutomationLogsSheet> createState() => _AutomationLogsSheetState();
}

class _AutomationLogsSheetState extends State<_AutomationLogsSheet> {
  static const _purple = Color(0xFF8B5CF6);
  bool _loading = true;
  List<dynamic> _logs = [];

  @override
  void initState() { super.initState(); _loadLogs(); }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().getAutomationLogs();
      final raw = res.data['data'];
      if (!mounted) return;
      setState(() => _logs = raw is List ? raw : (raw?['logs'] as List? ?? []));
    } catch (_) {
      if (!mounted) return;
      setState(() => _logs = const []);
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(child: CircularProgressIndicator(color: _purple))
        : _logs.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history_outlined, size: 48, color: AppColors.textGhost),
                SizedBox(height: 8),
                Text('No automation logs yet', style: TextStyle(fontSize: 14, color: AppColors.textGhost)),
                SizedBox(height: 4),
                Text('Logs appear here after rules run', style: TextStyle(fontSize: 12, color: AppColors.textGhost)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: _logs.length,
                itemBuilder: (_, i) {
                  final log = _logs[i] as Map<String, dynamic>;
                  final success = log['status'] == 'SUCCESS';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: (success ? AppColors.success : AppColors.danger).withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                        child: Icon(success ? Icons.check_circle_outline : Icons.error_outline, size: 18, color: success ? AppColors.success : AppColors.danger),
                      ),
                      title: Text(log['automationName'] as String? ?? 'Automation', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(log['message'] as String? ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                      trailing: Text(log['timestamp'] as String? ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textGhost)),
                    ),
                  );
                },
              );

    if (widget.embedded) return content;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Align(alignment: Alignment.centerLeft, child: Text('Automation Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 400, child: content),
        const SizedBox(height: 20),
      ]),
    );
  }
}
