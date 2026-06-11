import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';

class LeadFormsScreen extends ConsumerStatefulWidget {
  const LeadFormsScreen({super.key});
  @override
  ConsumerState<LeadFormsScreen> createState() => _LeadFormsScreenState();
}

class _LeadFormsScreenState extends ConsumerState<LeadFormsScreen> {
  List _forms = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get('/lead-forms', queryParameters: {'limit': 50});
      final d = res.data['data'];
      setState(() { _forms = (d is List ? d : d['forms'] ?? d['leadForms'] ?? []) as List; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Color _statusColor(String? s) {
    switch (s?.toUpperCase()) {
      case 'ACTIVE':  return AppColors.success;
      case 'PAUSED':  return AppColors.warning;
      default:        return AppColors.textGhost;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLight,
    appBar: AppBar(title: const Text('Lead Forms'), backgroundColor: Colors.white, foregroundColor: AppColors.textPrimary, elevation: 0),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.push('/lead-forms/create'),
      backgroundColor: const Color(0xFF14B8A6),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('Create Form', style: TextStyle(color: Colors.white)),
    ),
    body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(onRefresh: _load,
            child: _forms.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.dynamic_form_outlined, size: 48, color: AppColors.textGhost),
                    SizedBox(height: 12), Text('No lead forms yet', style: TextStyle(color: AppColors.textSec)),
                    SizedBox(height: 4), Text('Create forms to capture leads from your website', style: TextStyle(fontSize: 12, color: AppColors.textGhost))]))
                : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _forms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final f = _forms[i];
                      final status = f['status'] as String? ?? 'DRAFT';
                      return Container(padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF14B8A6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.dynamic_form_outlined, color: Color(0xFF14B8A6), size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(f['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                            Text('${f['submissionsCount'] ?? f['submissions'] ?? 0} submissions',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSec)),
                          ])),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(status)))),
                        ]));
                    })),
  );
}
