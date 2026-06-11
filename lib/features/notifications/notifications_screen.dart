import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/shimmer_list.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _loading = true;
  List<dynamic> _notifications = [];
  String _filter = 'ALL';

  static final _demo = [
    {'id': '1', 'type': 'INVOICE',    'title': 'Invoice Overdue',        'body': 'Invoice #INV-0042 from Raj Traders is 3 days overdue',        'read': false, 'createdAt': '2026-06-10T09:30:00Z'},
    {'id': '2', 'type': 'LEAD',       'title': 'New Lead Assigned',       'body': 'Lead "ABC Exports Ltd" has been assigned to you',              'read': false, 'createdAt': '2026-06-10T08:15:00Z'},
    {'id': '3', 'type': 'STOCK',      'title': 'Low Stock Alert',         'body': 'Product "HDPE Granules" is below reorder level (45 kg left)',   'read': true,  'createdAt': '2026-06-10T07:00:00Z'},
    {'id': '4', 'type': 'SUPPORT',    'title': 'Ticket Updated',          'body': 'Customer replied on ticket #TKT-0018',                         'read': false, 'createdAt': '2026-06-09T16:45:00Z'},
    {'id': '5', 'type': 'DEAL',       'title': 'Deal Won!',               'body': 'Deal "Summer Bulk Order - XYZ Corp" marked as WON',             'read': true,  'createdAt': '2026-06-09T14:00:00Z'},
    {'id': '6', 'type': 'PAYMENT',    'title': 'Payment Received',        'body': '₹45,000 received from Mehra Plastics against INV-0039',         'read': true,  'createdAt': '2026-06-09T11:30:00Z'},
    {'id': '7', 'type': 'TASK',       'title': 'Task Due Tomorrow',       'body': 'Task "Prepare quotation for XYZ" is due tomorrow',              'read': false, 'createdAt': '2026-06-09T09:00:00Z'},
    {'id': '8', 'type': 'AUTOMATION', 'title': 'Automation Triggered',    'body': 'Welcome email sent to new lead "Patel Industries"',             'read': true,  'createdAt': '2026-06-08T17:00:00Z'},
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().getNotifications();
      final raw = res.data['data'];
      if (!mounted) return;
      setState(() => _notifications = raw is List ? raw : (raw?['notifications'] as List? ?? []));
    } catch (_) {
      if (!mounted) return;
      setState(() => _notifications = List<Map<String, dynamic>>.from(_demo));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    try {
      await ApiClient().dio.post('/notifications/mark-all-read');
      _load();
    } catch (_) {
      setState(() {
        for (final n in _notifications) { (n as Map<String, dynamic>)['read'] = true; }
      });
    }
  }

  List<dynamic> get _filtered {
    if (_filter == 'ALL')    return _notifications;
    if (_filter == 'UNREAD') return _notifications.where((n) => (n as Map<String, dynamic>)['read'] != true).toList();
    return _notifications.where((n) => (n as Map<String, dynamic>)['type'] == _filter).toList();
  }

  int get _unreadCount => _notifications.where((n) => (n as Map<String, dynamic>)['read'] != true).length;

  Color _typeColor(String? t) {
    switch (t) {
      case 'INVOICE':    return AppColors.danger;
      case 'LEAD':       return AppColors.primary;
      case 'STOCK':      return AppColors.warning;
      case 'SUPPORT':    return AppColors.info;
      case 'DEAL':       return const Color(0xFF8B5CF6);
      case 'PAYMENT':    return AppColors.success;
      case 'TASK':       return AppColors.secondary;
      case 'AUTOMATION': return const Color(0xFF8B5CF6);
      default:           return AppColors.textGhost;
    }
  }

  IconData _typeIcon(String? t) {
    switch (t) {
      case 'INVOICE':    return Icons.receipt_long_outlined;
      case 'LEAD':       return Icons.person_add_outlined;
      case 'STOCK':      return Icons.inventory_outlined;
      case 'SUPPORT':    return Icons.headset_mic_outlined;
      case 'DEAL':       return Icons.handshake_outlined;
      case 'PAYMENT':    return Icons.payments_outlined;
      case 'TASK':       return Icons.task_alt_outlined;
      case 'AUTOMATION': return Icons.bolt_outlined;
      default:           return Icons.notifications_outlined;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)    return '${diff.inHours}h ago';
      if (diff.inDays < 7)      return '${diff.inDays}d ago';
      return DateFormat('d MMM').format(dt);
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Notifications'),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
              child: Text('$_unreadCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ]),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: {
              'ALL': 'All', 'UNREAD': 'Unread', 'INVOICE': 'Finance',
              'LEAD': 'Leads', 'STOCK': 'Stock', 'DEAL': 'Deals',
              'SUPPORT': 'Support', 'TASK': 'Tasks',
            }.entries.map((e) {
              final sel = _filter == e.key;
              final fc = e.key == 'ALL' ? AppColors.primary : e.key == 'UNREAD' ? AppColors.danger : _typeColor(e.key);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(e.value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : fc)),
                  selected: sel,
                  onSelected: (_) => setState(() => _filter = e.key),
                  backgroundColor: fc.withOpacity(0.08),
                  selectedColor: fc,
                  showCheckmark: false,
                  side: BorderSide(color: fc.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _loading
              ? const ShimmerList(itemHeight: 68)
              : _filtered.isEmpty
                  ? EmptyState(icon: Icons.notifications_none_outlined, message: 'No notifications', subtitle: 'You are all caught up!')
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final n = _filtered[i] as Map<String, dynamic>;
                          final isRead = n['read'] as bool? ?? true;
                          final type = n['type'] as String?;
                          final c = _typeColor(type);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isRead ? AppColors.cardLight : c.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isRead ? AppColors.border : c.withOpacity(0.3)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              onTap: () => setState(() => n['read'] = true),
                              leading: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: c.withOpacity(isRead ? 0.08 : 0.15), borderRadius: BorderRadius.circular(10)),
                                child: Icon(_typeIcon(type), size: 18, color: c),
                              ),
                              title: Row(children: [
                                Expanded(child: Text(
                                  n['title'] as String? ?? 'Notification',
                                  style: TextStyle(fontSize: 13, fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, color: AppColors.textPrimary),
                                )),
                                if (!isRead)
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                              ]),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const SizedBox(height: 2),
                                Text(n['body'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSec), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 3),
                                Text(_timeAgo(n['createdAt'] as String?), style: const TextStyle(fontSize: 10, color: AppColors.textGhost)),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}
