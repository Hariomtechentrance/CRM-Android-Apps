import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';

class EmailScreen extends ConsumerStatefulWidget {
  const EmailScreen({super.key});
  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  List _accounts = [], _emails = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final acRes = await ApiClient().dio.get('/email-accounts');
      final acData = acRes.data['data'];
      _accounts = (acData is List ? acData : acData['accounts'] ?? []) as List;
      if (_accounts.isNotEmpty) {
        final emRes = await ApiClient().dio.get('/email', queryParameters: {'limit': 30});
        final emData = emRes.data['data'];
        _emails = (emData is List ? emData : emData['emails'] ?? emData['messages'] ?? []) as List;
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLight,
    appBar: AppBar(title: const Text('Email'), backgroundColor: Colors.white, foregroundColor: AppColors.textPrimary, elevation: 0),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(
            onRefresh: _load,
            child: _accounts.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 72, height: 72,
                      decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.email_outlined, size: 36, color: AppColors.info)),
                    const SizedBox(height: 16),
                    const Text('No email account connected', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    const Text('Connect Gmail or SMTP via Settings → Email', style: TextStyle(fontSize: 13, color: AppColors.textSec), textAlign: TextAlign.center),
                  ]))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _emails.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final m = _emails[i];
                      final unread = m['read'] == false || m['isRead'] == false;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Text((m['from'] ?? m['sender'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
                        title: Text(m['subject'] ?? '(No subject)',
                            style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w400, fontSize: 13, color: AppColors.textPrimary)),
                        subtitle: Text(m['from'] ?? m['sender'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSec)),
                        trailing: unread ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)) : null,
                      );
                    }),
          ),
  );
}
