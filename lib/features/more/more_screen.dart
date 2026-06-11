import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class _Mod {
  final String label, subtitle, route;
  final IconData icon;
  final Color color;
  const _Mod({required this.label, required this.subtitle, required this.route, required this.icon, required this.color});
}

class _Cat {
  final String label;
  final List<_Mod> modules;
  const _Cat({required this.label, required this.modules});
}

const _c1 = Color(0xFFF97316);
const _c2 = Color(0xFF0EA5E9);
const _c3 = Color(0xFF25D366);
const _c4 = Color(0xFF8B5CF6);
const _c5 = Color(0xFFEC4899);
const _c6 = Color(0xFF14B8A6);

final _categories = [
  _Cat(label: 'Core', modules: [
    _Mod(label: 'Finance',         subtitle: 'Invoices & payments',     route: '/finance',        icon: Icons.receipt_long,           color: AppColors.danger),
    _Mod(label: 'Purchase',        subtitle: 'POs & vendors',           route: '/purchase',       icon: Icons.shopping_cart_outlined,  color: AppColors.secondary),
    _Mod(label: 'Sales',           subtitle: 'Orders & dispatch',       route: '/sales',          icon: Icons.local_shipping_outlined, color: AppColors.warning),
    _Mod(label: 'Store (Inward)',  subtitle: 'Goods receipt & inward',  route: '/store',          icon: Icons.move_to_inbox_outlined,  color: AppColors.success),
    _Mod(label: 'Warehouse',       subtitle: 'Multi-location stock',    route: '/warehouse',      icon: Icons.warehouse_outlined,      color: AppColors.warning),
    _Mod(label: 'GST Reports',     subtitle: 'GSTR-1, GSTR-3B',        route: '/gst',            icon: Icons.description_outlined,    color: AppColors.success),
  ]),
  _Cat(label: 'Growth', modules: [
    _Mod(label: 'Leads',           subtitle: 'Pipeline & follow-ups',   route: '/leads',          icon: Icons.trending_up,             color: AppColors.primary),
    _Mod(label: 'Deals',           subtitle: 'Deal pipeline & CRM',     route: '/deals',          icon: Icons.handshake_outlined,      color: _c4),
    _Mod(label: 'Quotations',      subtitle: 'Proposals & quotes',      route: '/quotations',     icon: Icons.request_quote_outlined,  color: AppColors.info),
    _Mod(label: 'Support',         subtitle: 'Tickets & SLA',           route: '/support',        icon: Icons.headset_mic_outlined,    color: AppColors.danger),
    _Mod(label: 'E-commerce',      subtitle: 'Shopify & Flipkart',      route: '/ecommerce',      icon: Icons.storefront_outlined,     color: AppColors.secondary),
    _Mod(label: 'Reports',         subtitle: 'Analytics & exports',     route: '/reports',        icon: Icons.bar_chart_outlined,      color: AppColors.info),
  ]),
  _Cat(label: 'Operations', modules: [
    _Mod(label: 'HR & Payroll',    subtitle: 'Employees & attendance',  route: '/hr',             icon: Icons.badge_outlined,          color: AppColors.info),
    _Mod(label: 'Projects',        subtitle: 'Tasks & milestones',      route: '/projects',       icon: Icons.task_alt_outlined,       color: AppColors.secondary),
    _Mod(label: 'Activities',      subtitle: 'Timeline & logs',         route: '/activities',     icon: Icons.timeline_outlined,       color: AppColors.secondary),
    _Mod(label: 'Appointments',    subtitle: 'Calendar & scheduling',   route: '/appointments',   icon: Icons.calendar_today_outlined, color: AppColors.primary),
    _Mod(label: 'Point of Sale',   subtitle: 'Retail billing & POS',   route: '/pos',            icon: Icons.point_of_sale_outlined,  color: AppColors.success),
    _Mod(label: 'Automations',     subtitle: 'Workflow rules',          route: '/automations',    icon: Icons.bolt_outlined,           color: _c4),
  ]),
  _Cat(label: 'Industry', modules: [
    _Mod(label: 'Import/Export',   subtitle: 'Trade docs & shipments',  route: '/import-export',  icon: Icons.directions_boat_outlined,color: AppColors.success),
    _Mod(label: 'Retail & Fashion',subtitle: 'Variants & collections',  route: '/retail',         icon: Icons.checkroom_outlined,      color: _c4),
    _Mod(label: 'Tele-calling',    subtitle: 'Call logs & campaigns',   route: '/telecalling',    icon: Icons.phone_in_talk_outlined,  color: AppColors.success),
    _Mod(label: 'Services',        subtitle: 'Catalog & AMC contracts', route: '/services',       icon: Icons.miscellaneous_services_outlined, color: AppColors.warning),
    _Mod(label: 'Stock Market',    subtitle: 'Trade calls & advisory',  route: '/stock-market',   icon: Icons.candlestick_chart_outlined, color: AppColors.danger),
    _Mod(label: 'Health & Clinic', subtitle: 'Patients & OPD',         route: '/health',         icon: Icons.local_hospital_outlined, color: _c5),
  ]),
  _Cat(label: 'Communication', modules: [
    _Mod(label: 'WhatsApp',        subtitle: 'Messages & campaigns',    route: '/whatsapp',       icon: Icons.chat_bubble_outline,     color: _c3),
    _Mod(label: 'Email',           subtitle: 'Inbox & campaigns',       route: '/email',          icon: Icons.email_outlined,          color: AppColors.info),
    _Mod(label: 'Lead Forms',      subtitle: 'Capture & web forms',     route: '/lead-forms',     icon: Icons.dynamic_form_outlined,   color: _c6),
    _Mod(label: 'Documents',       subtitle: 'Files & contracts',       route: '/documents',      icon: Icons.folder_open_outlined,    color: AppColors.info),
  ]),
  _Cat(label: 'Food & Hospitality', modules: [
    _Mod(label: 'Restaurant POS',  subtitle: 'KOT, tables & billing',   route: '/restaurant',     icon: Icons.restaurant_outlined,     color: _c1),
    _Mod(label: 'Hotel / Resort',  subtitle: 'Rooms & bookings',        route: '/hotel',          icon: Icons.hotel_outlined,          color: _c2),
  ]),
  _Cat(label: 'Config', modules: [
    _Mod(label: 'Settings',        subtitle: 'Org & team config',       route: '/settings',       icon: Icons.settings_outlined,       color: AppColors.textSec),
  ]),
];

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String _query = '';

  List<_Mod> get _filtered {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _categories.expand((c) => c.modules).where((m) =>
      m.label.toLowerCase().contains(q) || m.subtitle.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverToBoxAdapter(
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search modules...',
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textGhost),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              fillColor: AppColors.cardLight,
              filled: true,
            ),
          ),
        ),
      ),
      if (_query.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _ModuleCard(mod: _filtered[i]),
              childCount: _filtered.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _CategorySection(cat: _categories[i]),
              childCount: _categories.length,
            ),
          ),
        ),
    ],
  );
}

class _CategorySection extends StatelessWidget {
  final _Cat cat;
  const _CategorySection({required this.cat});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(cat.label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textGhost, letterSpacing: 0.8)),
      ),
      GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: cat.modules.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
        ),
        itemBuilder: (ctx, i) => _ModuleCard(mod: cat.modules[i]),
      ),
    ],
  );
}

class _ModuleCard extends StatelessWidget {
  final _Mod mod;
  const _ModuleCard({required this.mod});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push(mod.route),
    borderRadius: BorderRadius.circular(14),
    child: Container(
      decoration: BoxDecoration(
        color: mod.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mod.color.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: mod.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(mod.icon, size: 18, color: mod.color),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mod.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(mod.subtitle,
              style: const TextStyle(fontSize: 9, color: AppColors.textGhost),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ],
      ),
    ),
  );
}
