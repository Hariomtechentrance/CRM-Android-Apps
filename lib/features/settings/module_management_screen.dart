import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';
import '../auth/auth_notifier.dart';

class _Module {
  final String name, description, slug;
  final IconData icon;
  final Color color;
  bool enabled;
  _Module({
    required this.name,
    required this.description,
    required this.slug,
    required this.icon,
    required this.color,
    this.enabled = true,
  });
}

class ModuleManagementScreen extends ConsumerStatefulWidget {
  const ModuleManagementScreen({super.key});
  @override
  ConsumerState<ModuleManagementScreen> createState() => _ModuleManagementScreenState();
}

class _ModuleManagementScreenState extends ConsumerState<ModuleManagementScreen> {
  bool _loading = false;
  bool _saving = false;

  final List<_Module> _modules = [
    _Module(name: 'CRM',            description: 'Parties, contacts & communications',   slug: 'crm',           icon: Icons.people_outline,           color: AppColors.primary,   enabled: true),
    _Module(name: 'Inventory',      description: 'Products, stock & categories',          slug: 'inventory',     icon: Icons.inventory_2_outlined,     color: AppColors.success,   enabled: true),
    _Module(name: 'Finance',        description: 'Invoices, payments & reports',          slug: 'finance',       icon: Icons.receipt_long_outlined,    color: AppColors.danger,    enabled: true),
    _Module(name: 'Leads',          description: 'Pipeline, activities & kanban',         slug: 'leads',         icon: Icons.trending_up_outlined,     color: AppColors.primary,   enabled: true),
    _Module(name: 'HR & Payroll',   description: 'Employees, attendance & leaves',        slug: 'hr',            icon: Icons.badge_outlined,           color: AppColors.info,      enabled: true),
    _Module(name: 'Purchase',       description: 'Purchase orders & vendors',             slug: 'purchase',      icon: Icons.shopping_cart_outlined,   color: AppColors.secondary, enabled: true),
    _Module(name: 'Sales',          description: 'Sales orders & dispatch',               slug: 'sales',         icon: Icons.local_shipping_outlined,  color: AppColors.warning,   enabled: true),
    _Module(name: 'Projects',       description: 'Tasks, milestones & kanban',            slug: 'projects',      icon: Icons.task_alt_outlined,        color: AppColors.secondary, enabled: true),
    _Module(name: 'Support',        description: 'Tickets, SLA & resolution',             slug: 'support',       icon: Icons.headset_mic_outlined,     color: AppColors.danger,    enabled: true),
    _Module(name: 'Warehouse',      description: 'Multi-location stock management',       slug: 'warehouse',     icon: Icons.warehouse_outlined,       color: AppColors.warning,   enabled: false),
    _Module(name: 'GST Reports',    description: 'GSTR-1, GSTR-3B filing',                slug: 'gst',           icon: Icons.description_outlined,     color: AppColors.success,   enabled: true),
    _Module(name: 'Reports',        description: 'Analytics & data exports',              slug: 'reports',       icon: Icons.bar_chart_outlined,       color: AppColors.info,      enabled: true),
    _Module(name: 'Appointments',   description: 'Calendar & scheduling',                  slug: 'appointments',  icon: Icons.calendar_today_outlined,  color: AppColors.primary,   enabled: false),
    _Module(name: 'WhatsApp',       description: 'Messages & campaigns',                  slug: 'whatsapp',      icon: Icons.chat_bubble_outline,      color: const Color(0xFF25D366), enabled: false),
    _Module(name: 'E-commerce',     description: 'Shopify & Flipkart sync',               slug: 'ecommerce',     icon: Icons.storefront_outlined,      color: AppColors.secondary, enabled: false),
    _Module(name: 'Restaurant POS', description: 'KOT, tables & billing',                 slug: 'restaurant',    icon: Icons.restaurant_outlined,      color: const Color(0xFFF97316), enabled: false),
    _Module(name: 'Hotel / Resort', description: 'Room bookings & housekeeping',          slug: 'hotel',         icon: Icons.hotel_outlined,           color: const Color(0xFF0EA5E9), enabled: false),
    _Module(name: 'Documents',      description: 'Files, contracts & storage',            slug: 'documents',     icon: Icons.folder_open_outlined,     color: AppColors.info,      enabled: false),
  ];

  @override
  void initState() {
    super.initState();
    _loadFromOrg();
  }

  Future<void> _loadFromOrg() async {
    setState(() => _loading = true);
    try {
      final user = ref.read(authNotifierProvider).valueOrNull?.user;
      final enabledModules = user?.activeOrg?.enabledModules ?? [];
      if (enabledModules.isNotEmpty) {
        for (final m in _modules) {
          m.enabled = enabledModules.contains(m.slug);
        }
      } else {
        // Load from API if not in local cache
        final res = await ApiClient().getOrganization();
        final data = res.data['data'] as Map<String, dynamic>? ?? {};
        final List<dynamic> apiModules = data['enabledModules'] as List? ?? [];
        if (apiModules.isNotEmpty) {
          for (final m in _modules) {
            m.enabled = apiModules.contains(m.slug);
          }
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Modules & Features'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                )
              : TextButton(
                  onPressed: _saveChanges,
                  child: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.info.withOpacity(0.2)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.info),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Enable or disable modules for your organization.',
                      style: TextStyle(fontSize: 12, color: AppColors.info),
                    )),
                  ]),
                ),
                ..._modules.map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: m.enabled ? m.color.withOpacity(0.2) : AppColors.border),
                  ),
                  child: SwitchListTile(
                    value: m.enabled,
                    onChanged: (v) => setState(() => m.enabled = v),
                    activeColor: m.color,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    secondary: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: m.enabled ? m.color.withOpacity(0.1) : AppColors.bgLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(m.icon, size: 18, color: m.enabled ? m.color : AppColors.textGhost),
                    ),
                    title: Text(m.name, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: m.enabled ? AppColors.textPrimary : AppColors.textGhost,
                    )),
                    subtitle: Text(m.description, style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
                  ),
                )),
              ],
            ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    final enabledSlugs = _modules.where((m) => m.enabled).map((m) => m.slug).toList();
    try {
      await ApiClient().updateModules(enabledSlugs);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Module settings saved'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to save. Please try again.'),
        backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
