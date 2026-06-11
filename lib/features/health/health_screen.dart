import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});
  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _patients = [], _opd = [];
  bool _loadingP = true, _loadingO = true;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _loadPatients(); _loadOpd(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadPatients() async {
    setState(() => _loadingP = true);
    try {
      final res = await ApiClient().dio.get('/health/patients', queryParameters: {'page': 1, 'limit': 50});
      final d = res.data['data'];
      setState(() { _patients = (d is List ? d : d['patients'] ?? []) as List; _loadingP = false; });
    } catch (_) { setState(() => _loadingP = false); }
  }

  Future<void> _loadOpd() async {
    setState(() => _loadingO = true);
    try {
      final res = await ApiClient().dio.get('/health/opd', queryParameters: {'limit': 50});
      final d = res.data['data'];
      setState(() { _opd = (d is List ? d : d['visits'] ?? d['opd'] ?? []) as List; _loadingO = false; });
    } catch (_) { setState(() => _loadingO = false); }
  }

  Color _opdColor(String? s) {
    switch (s?.toUpperCase()) {
      case 'WAITING': return AppColors.warning;
      case 'IN_PROGRESS': return AppColors.info;
      case 'COMPLETED': return AppColors.success;
      default: return AppColors.textGhost;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLight,
    appBar: AppBar(title: const Text('Health & Clinic'), backgroundColor: Colors.white, foregroundColor: AppColors.textPrimary, elevation: 0,
      bottom: TabBar(controller: _tabs, labelColor: AppColors.primary, unselectedLabelColor: AppColors.textSec, indicatorColor: AppColors.primary,
        tabs: const [Tab(text: 'Patients'), Tab(text: 'OPD')])),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.push('/health/add-patient'),
      backgroundColor: const Color(0xFFEC4899),
      icon: const Icon(Icons.person_add_outlined, color: Colors.white),
      label: const Text('New Patient', style: TextStyle(color: Colors.white)),
    ),
    body: TabBarView(controller: _tabs, children: [
      _loadingP ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(onRefresh: _loadPatients,
            child: _patients.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.local_hospital_outlined, size: 48, color: AppColors.textGhost),
                    SizedBox(height: 12), Text('No patients registered', style: TextStyle(color: AppColors.textSec))]))
                : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _patients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final p = _patients[i];
                      return Container(padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          CircleAvatar(radius: 22, backgroundColor: const Color(0xFFEC4899).withOpacity(0.15),
                            child: Text((p['name'] ?? 'P').toString().substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.w700))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                            Text('${p['age'] ?? '-'} yrs  •  ${p['gender'] ?? '-'}  •  ${p['phone'] ?? '-'}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSec)),
                          ])),
                        ]));
                    })),
      _loadingO ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(onRefresh: _loadOpd,
            child: _opd.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.medical_services_outlined, size: 48, color: AppColors.textGhost),
                    SizedBox(height: 12), Text('No OPD visits today', style: TextStyle(color: AppColors.textSec))]))
                : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _opd.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final v = _opd[i];
                      final status = v['status'] as String? ?? 'WAITING';
                      return Container(padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          Container(width: 36, height: 36, decoration: BoxDecoration(color: _opdColor(status).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text('#${v['tokenNo'] ?? i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _opdColor(status))))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(v['patientName'] ?? v['patient']?['name'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                            Text('Dr. ${v['doctor'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppColors.textSec)),
                          ])),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _opdColor(status).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: Text(status.replaceAll('_', ' '), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _opdColor(status)))),
                        ]));
                    })),
    ]),
  );
}
