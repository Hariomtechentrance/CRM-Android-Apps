import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/shimmer_list.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});
  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen> {
  bool _loading = true;
  List<dynamic> _quotes = [];
  String _statusFilter = 'ALL';
  final _fmt = NumberFormat('#,##,###', 'en_IN');

  static final _demo = [
    {'id': 'q1', 'number': 'QT-0001', 'partyName': 'Raj Traders',        'amount': 85000,  'status': 'SENT',     'date': '2026-06-08', 'validDays': 30, 'notes': 'Supply of raw materials'},
    {'id': 'q2', 'number': 'QT-0002', 'partyName': 'Mehra Plastics',     'amount': 142000, 'status': 'ACCEPTED', 'date': '2026-06-07', 'validDays': 15, 'notes': ''},
    {'id': 'q3', 'number': 'QT-0003', 'partyName': 'Global Imports Ltd', 'amount': 38500,  'status': 'DRAFT',    'date': '2026-06-06', 'validDays': 30, 'notes': 'Pending final pricing'},
    {'id': 'q4', 'number': 'QT-0004', 'partyName': 'XYZ Corporation',    'amount': 210000, 'status': 'REJECTED', 'date': '2026-06-05', 'validDays': 30, 'notes': ''},
    {'id': 'q5', 'number': 'QT-0005', 'partyName': 'Patel Industries',   'amount': 67500,  'status': 'SENT',     'date': '2026-06-04', 'validDays': 7,  'notes': 'Urgent'},
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().getQuotations();
      final raw = res.data['data'];
      if (!mounted) return;
      setState(() => _quotes = raw is List ? raw : (raw?['quotations'] as List? ?? []));
    } catch (_) {
      if (!mounted) return;
      setState(() => _quotes = List<Map<String, dynamic>>.from(_demo));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'ACCEPTED': return AppColors.success;
      case 'SENT':     return AppColors.primary;
      case 'REJECTED': return AppColors.danger;
      case 'DRAFT':    return AppColors.textGhost;
      case 'EXPIRED':  return AppColors.warning;
      default:         return AppColors.textSec;
    }
  }

  List<dynamic> get _filtered => _statusFilter == 'ALL'
      ? _quotes
      : _quotes.where((q) => (q as Map<String, dynamic>)['status'] == _statusFilter).toList();

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateQuotationSheet(onCreated: _load),
    );
  }

  void _showDetail(Map<String, dynamic> quote) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _QuotationDetailSheet(
        quote: quote, fmt: _fmt, statusColor: _statusColor, onUpdate: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Quotations'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showCreateSheet),
        ],
      ),
      body: Column(children: [
        if (!_loading && _quotes.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.cardLight,
            child: Row(children: [
              _sumItem('Total', _quotes.length.toString(), AppColors.primary),
              const SizedBox(width: 16),
              _sumItem('Accepted', '${_quotes.where((q) => (q as Map<String, dynamic>)['status'] == 'ACCEPTED').length}', AppColors.success),
              const SizedBox(width: 16),
              _sumItem('Sent', '${_quotes.where((q) => (q as Map<String, dynamic>)['status'] == 'SENT').length}', AppColors.warning),
              const Spacer(),
              Text('₹${_fmt.format(_quotes.fold<double>(0, (s, q) => s + ((q['amount'] as num? ?? 0).toDouble())))}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ]),
          ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: ['ALL', 'DRAFT', 'SENT', 'ACCEPTED', 'REJECTED', 'EXPIRED'].map((s) {
              final sel = _statusFilter == s;
              final c = s == 'ALL' ? AppColors.info : _statusColor(s);
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
          child: _loading
              ? const ShimmerList(itemHeight: 72)
              : _filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.request_quote_outlined,
                      message: 'No quotations found',
                      subtitle: 'Create proposals and send to customers',
                      actionLabel: 'New Quotation',
                      onAction: _showCreateSheet,
                    )
                  : RefreshIndicator(
                      color: AppColors.info,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final q = _filtered[i] as Map<String, dynamic>;
                          final status = q['status'] as String? ?? 'DRAFT';
                          final c = _statusColor(status);
                          final amount = (q['amount'] as num? ?? 0).toDouble();
                          return Dismissible(
                            key: Key(q['id'] as String? ?? '$i'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDelete(q),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.delete_outline, color: AppColors.danger),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                onTap: () => _showDetail(q),
                                leading: Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: Icon(Icons.request_quote_outlined, size: 18, color: c),
                                ),
                                title: Text(q['number'] as String? ?? '#', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                subtitle: Text(q['partyName'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textGhost)),
                                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
                                  ),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: AppColors.info,
        icon: const Icon(Icons.request_quote_outlined, color: Colors.white),
        label: const Text('New Quote', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<bool> _confirmDelete(Map<String, dynamic> quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text('Delete ${quote['number']}? This cannot be undone.'),
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
        await ApiClient().deleteQuotation(quote['id'] as String);
        _load();
        return true;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to delete'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
    return false;
  }

  Widget _sumItem(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGhost)),
    ],
  );
}

// ── Create Quotation Sheet ────────────────────────────────────────────────────
class _CreateQuotationSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateQuotationSheet({required this.onCreated});
  @override
  State<_CreateQuotationSheet> createState() => _CreateQuotationSheetState();
}

class _CreateQuotationSheetState extends State<_CreateQuotationSheet> {
  final _partyCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  int _validDays = 30;
  bool _loading = false;

  @override
  void dispose() { _partyCtrl.dispose(); _amountCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _submit(String status) async {
    if (_partyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Customer name is required'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiClient().createQuotation({
        'partyName': _partyCtrl.text.trim(),
        'amount':    double.tryParse(_amountCtrl.text.trim()) ?? 0,
        'notes':     _notesCtrl.text.trim(),
        'validDays': _validDays,
        'status':    status,
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'SENT' ? 'Quotation created & sent' : 'Quotation saved as draft'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to create quotation'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
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
            const Text('New Quotation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _partyCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Customer / Party Name *',
              prefixIcon: Icon(Icons.business_outlined, size: 18, color: AppColors.textGhost),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Total Amount (₹)',
              prefixIcon: Icon(Icons.currency_rupee, size: 18, color: AppColors.textGhost),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _validDays,
            decoration: const InputDecoration(
              labelText: 'Valid For',
              prefixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textGhost),
            ),
            items: const [
              DropdownMenuItem(value: 7,  child: Text('7 days')),
              DropdownMenuItem(value: 15, child: Text('15 days')),
              DropdownMenuItem(value: 30, child: Text('30 days')),
              DropdownMenuItem(value: 60, child: Text('60 days')),
              DropdownMenuItem(value: 90, child: Text('90 days')),
            ],
            onChanged: (v) => setState(() => _validDays = v ?? 30),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.notes_outlined, size: 18, color: AppColors.textGhost),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => _submit('DRAFT'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: const BorderSide(color: AppColors.info),
                  foregroundColor: AppColors.info,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Save Draft'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loading ? null : () => _submit('SENT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info, foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_outlined, size: 18),
                label: const Text('Send to Customer'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Quotation Detail Sheet ────────────────────────────────────────────────────
class _QuotationDetailSheet extends StatelessWidget {
  final Map<String, dynamic> quote;
  final NumberFormat fmt;
  final Color Function(String?) statusColor;
  final VoidCallback onUpdate;
  const _QuotationDetailSheet({required this.quote, required this.fmt, required this.statusColor, required this.onUpdate});

  Future<void> _updateStatus(BuildContext context, String status) async {
    Navigator.pop(context);
    try {
      await ApiClient().updateQuotation(quote['id'] as String, {'status': status});
      onUpdate();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Quotation marked as $status'),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Update failed'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _sendQuotation(BuildContext context) async {
    Navigator.pop(context);
    try {
      await ApiClient().sendQuotation(quote['id'] as String);
      onUpdate();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quotation sent to customer'),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to send'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = quote['status'] as String? ?? 'DRAFT';
    final c = statusColor(status);
    final amount = (quote['amount'] as num? ?? 0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.request_quote_outlined, color: c, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(quote['number'] as String? ?? '#', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(quote['partyName'] as String? ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textGhost)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
          ),
        ]),
        const SizedBox(height: 16),
        _row('Amount',    '₹${fmt.format(amount)}'),
        _row('Date',      quote['date'] as String? ?? ''),
        _row('Valid For', '${quote['validDays'] ?? 30} days'),
        if ((quote['notes'] as String? ?? '').isNotEmpty) _row('Notes', quote['notes'] as String),
        const Divider(height: 24),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (status == 'DRAFT') ...[
            _actionBtn(context, 'Send to Customer', Icons.send_outlined,  AppColors.primary, () => _sendQuotation(context)),
          ],
          if (status == 'SENT') ...[
            _actionBtn(context, 'Mark Accepted', Icons.check_circle_outline, AppColors.success, () => _updateStatus(context, 'ACCEPTED')),
            _actionBtn(context, 'Mark Rejected', Icons.cancel_outlined,      AppColors.danger,  () => _updateStatus(context, 'REJECTED')),
          ],
          if (status == 'ACCEPTED')
            _actionBtn(context, 'Convert to Invoice', Icons.receipt_long_outlined, AppColors.info, () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Create invoice from Finance module'), behavior: SnackBarBehavior.floating,
              ));
            }),
        ]),
      ]),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGhost))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
    ]),
  );

  Widget _actionBtn(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) =>
      ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1), foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: color.withOpacity(0.3))),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        icon: Icon(icon, size: 14),
        label: Text(label),
      );
}
