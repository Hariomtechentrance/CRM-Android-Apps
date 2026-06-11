import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../data/services/api_client.dart';
import '../../features/auth/auth_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(authNotifierProvider).valueOrNull?.user;
    final org       = user?.activeOrg;
    final themeMode = ref.watch(themeModeProvider);
    final isDark    = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // ── Profile card ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.name ?? 'User',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(user?.email ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
              if (org != null) ...[
                const SizedBox(height: 2),
                Text('${org.name} • ${org.role}',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
              ],
            ])),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white70),
              onPressed: () => context.push('/settings/profile'),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ── Organization ──────────────────────────────────────
        _section('Organization', [
          _tile(Icons.business_outlined,  'Organization Profile',   AppColors.primary,   () => context.push('/settings/org')),
          _tile(Icons.people_outline,     'Team Members',           AppColors.info,      () => context.push('/settings/team')),
          _tile(Icons.extension_outlined, 'Modules & Features',     AppColors.secondary, () => context.push('/settings/modules')),
          _tile(Icons.attach_money,       'Subscription & Billing', AppColors.success,   () => _showSubscriptionDialog(context)),
        ]),

        const SizedBox(height: 16),

        // ── App Settings ──────────────────────────────────────
        _section('App Settings', [
          _tile(Icons.notifications_outlined, 'Notifications',    AppColors.warning, () => _showNotificationsDialog(context)),
          _tile(Icons.language_outlined,       'Language',         AppColors.info,    () => _showLanguageDialog(context)),
          _tile(Icons.currency_rupee,          'Currency & Units', AppColors.primary, () => _showCurrencyDialog(context, org?.currency ?? 'INR')),
          // Theme tile uses a trailing Switch instead of navigating
          _themeTile(isDark, () {
            final next = isDark ? ThemeMode.light : ThemeMode.dark;
            ref.read(themeModeProvider.notifier).state = next;
            SharedPreferences.getInstance()
                .then((p) => p.setBool('isDarkMode', next == ThemeMode.dark));
          }),
        ]),

        const SizedBox(height: 16),

        // ── Data ─────────────────────────────────────────────
        _section('Data', [
          _tile(Icons.backup_outlined,  'Backup & Export', AppColors.success, () => _showBackupDialog(context)),
          _tile(Icons.import_export,    'Import Data',     AppColors.primary, () => _showImportDialog(context)),
          _tile(Icons.restore_outlined, 'Restore Data',    AppColors.info,    () => _showRestoreDialog(context)),
        ]),

        const SizedBox(height: 16),

        // ── Help & Support ────────────────────────────────────
        _section('Help & Support', [
          _tile(Icons.help_outline,  'Help Center',     AppColors.info,    () => _showHelpCenter(context)),
          _tile(Icons.chat_outlined, 'Contact Support', AppColors.success,  () => _showContactSupport(context)),
          _tile(Icons.star_outline,  'Rate the App',    AppColors.warning,  () => _showRateApp(context)),
          _tile(Icons.info_outline,  'About FlowCRM',   AppColors.textSec,  () => _showAbout(context)),
        ]),

        const SizedBox(height: 16),

        // ── Account ───────────────────────────────────────────
        _section('Account', [
          _tile(Icons.person_outlined, 'Edit Profile',    AppColors.primary, () => context.push('/settings/profile')),
          _tile(Icons.lock_outlined,   'Change Password', AppColors.warning,  () => _showChangePassword(context)),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.logout, size: 18, color: AppColors.danger),
            ),
            title: const Text('Sign Out',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.danger)),
            trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.danger),
            onTap: () => _confirmLogout(context, ref),
          ),
        ]),

        const SizedBox(height: 20),
        const Center(
            child: Text('FlowCRM v1.0.0',
                style: TextStyle(fontSize: 12, color: AppColors.textGhost))),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Section / tile helpers ─────────────────────────────────────
  Widget _section(String title, List<Widget> tiles) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(title,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textGhost,
                letterSpacing: 0.5)),
      ),
      Container(
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: tiles.asMap().entries.map((e) {
            final isLast = e.key == tiles.length - 1;
            return Column(children: [
              e.value,
              if (!isLast) const Divider(height: 1, indent: 54, color: AppColors.border),
            ]);
          }).toList(),
        ),
      ),
    ],
  );

  Widget _tile(IconData icon, String label, Color c, VoidCallback onTap) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 18, color: c),
    ),
    title: Text(label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
    trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textGhost),
    onTap: onTap,
  );

  Widget _themeTile(bool isDark, VoidCallback onToggle) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
          color: AppColors.textSec.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(isDark ? Icons.dark_mode : Icons.light_mode_outlined,
          size: 18, color: AppColors.textSec),
    ),
    title: Text(isDark ? 'Dark Mode' : 'Light Mode',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
    trailing: Switch(
      value: isDark,
      onChanged: (_) => onToggle(),
      activeColor: AppColors.primary,
    ),
    onTap: onToggle,
  );

  // ── Logout ─────────────────────────────────────────────────────
  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authNotifierProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  // ── Subscription & Billing ─────────────────────────────────────
  void _showSubscriptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Subscription & Billing',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              const Text('Free Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Up to 5 team members • 1,000 records',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
            ]),
          ),
          const SizedBox(height: 16),
          _infoRow(Icons.check_circle_outline, 'CRM & Inventory included', AppColors.success),
          _infoRow(Icons.check_circle_outline, 'Finance & Invoicing included', AppColors.success),
          _infoRow(Icons.lock_outline, 'Advanced modules — Pro plan', AppColors.textGhost),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Pro & Enterprise plans coming soon. You will be notified when upgrades are available.',
              style: TextStyle(fontSize: 11, color: AppColors.info),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  // ── Notifications ──────────────────────────────────────────────
  void _showNotificationsDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;

    bool push      = prefs.getBool('notif_push')      ?? true;
    bool email     = prefs.getBool('notif_email')     ?? true;
    bool marketing = prefs.getBool('notif_marketing') ?? false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Notifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _notifTile('Push Notifications', 'Alerts on new leads, invoices & activities',
                Icons.notifications_outlined, push, (v) {
              setState(() => push = v);
              prefs.setBool('notif_push', v);
            }),
            const Divider(height: 1),
            _notifTile('Email Notifications', 'Weekly summary & important updates',
                Icons.email_outlined, email, (v) {
              setState(() => email = v);
              prefs.setBool('notif_email', v);
            }),
            const Divider(height: 1),
            _notifTile('Marketing & Tips', 'Product tips and feature announcements',
                Icons.campaign_outlined, marketing, (v) {
              setState(() => marketing = v);
              prefs.setBool('notif_marketing', v);
            }),
          ]),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifTile(String title, String subtitle, IconData icon, bool value,
      ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, size: 20, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGhost)),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      );

  // ── Language ───────────────────────────────────────────────────
  void _showLanguageDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;

    String selected = prefs.getString('language') ?? 'en';
    final languages = [
      {'code': 'en',  'label': 'English',  'available': true},
      {'code': 'hi',  'label': 'हिन्दी (Hindi)',   'available': false},
      {'code': 'gu',  'label': 'ગુજરાતી (Gujarati)', 'available': false},
      {'code': 'mr',  'label': 'मराठी (Marathi)',   'available': false},
      {'code': 'ta',  'label': 'தமிழ் (Tamil)',    'available': false},
      {'code': 'te',  'label': 'తెలుగు (Telugu)',   'available': false},
    ];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Language',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((lang) {
              final available = lang['available'] as bool;
              return RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: lang['code'] as String,
                groupValue: selected,
                onChanged: available
                    ? (v) {
                        setState(() => selected = v!);
                        prefs.setString('language', v!);
                      }
                    : null,
                title: Text(lang['label'] as String,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: available ? AppColors.textPrimary : AppColors.textGhost)),
                subtitle: available
                    ? null
                    : const Text('Coming soon',
                        style: TextStyle(fontSize: 10, color: AppColors.textGhost)),
                activeColor: AppColors.primary,
              );
            }).toList(),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Language set to ${languages.firstWhere((l) => l['code'] == selected)['label']}'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Currency & Units ───────────────────────────────────────────
  void _showCurrencyDialog(BuildContext context, String currentCurrency) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Currency & Units',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _infoRow(Icons.currency_exchange_outlined, 'Active currency: $currentCurrency', AppColors.primary),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Currency is set per organization. To change it, go to Organization Profile → Currency.',
              style: TextStyle(fontSize: 12, color: AppColors.info),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/settings/org');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Open Org Settings'),
          ),
        ],
      ),
    );
  }

  // ── Backup & Export ────────────────────────────────────────────
  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backup & Export',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _exportOption(context, Icons.people_outline,         'Export Contacts (CSV)',  AppColors.primary),
          _exportOption(context, Icons.receipt_long_outlined,  'Export Invoices (CSV)',  AppColors.danger),
          _exportOption(context, Icons.inventory_2_outlined,   'Export Products (CSV)',  AppColors.success),
          _exportOption(context, Icons.trending_up_outlined,   'Export Leads (CSV)',     AppColors.warning),
          const Divider(height: 20),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Exports are processed in the background and emailed to your registered address.',
              style: TextStyle(fontSize: 11, color: AppColors.success),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _exportOption(BuildContext context, IconData icon, String label, Color color) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.download_outlined, size: 16, color: AppColors.textGhost),
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$label export queued — you\'ll receive it by email shortly.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ));
        },
      );

  // ── Import Data ────────────────────────────────────────────────
  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import Data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.upload_file_outlined, size: 48, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('Import contacts, products, and invoices from CSV or Excel files.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSec)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Bulk import is coming soon. For now, please add records individually or contact support for assisted migration.',
              style: TextStyle(fontSize: 11, color: AppColors.warning),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  // ── Restore Data ───────────────────────────────────────────────
  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          SizedBox(width: 8),
          Text('Restore Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Restoring data will overwrite all current records. This action cannot be undone.',
            style: TextStyle(fontSize: 13, color: AppColors.textSec),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Data restore from backup files is coming soon. Please contact support@flowcrm.com for manual restore assistance.',
              style: TextStyle(fontSize: 11, color: AppColors.info),
            ),
          ),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Help Center ────────────────────────────────────────────────
  void _showHelpCenter(BuildContext context) {
    final faqs = [
      ('How do I add a new customer?',
          'Go to CRM → tap the + button → fill in the party details and save.'),
      ('How do I create an invoice?',
          'Go to Finance → Create Invoice → select customer, add items, and tap Save.'),
      ('How do I add team members?',
          'Go to Settings → Team Members → tap Invite Member and enter the email.'),
      ('How do I change my organization currency?',
          'Go to Settings → Organization Profile → change Currency and save.'),
      ('Can I use the app offline?',
          'The app requires an internet connection for data sync. Offline support is on our roadmap.'),
      ('How do I reset my password?',
          'On the login screen, tap "Forgot Password" and follow the email instructions.'),
    ];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Help Center',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: faqs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(faqs[i].$1,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              children: [
                Text(faqs[i].$2,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSec)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── Contact Support ────────────────────────────────────────────
  void _showContactSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Contact Support',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('We\'re here to help! Reach us through any channel below.',
              style: TextStyle(fontSize: 13, color: AppColors.textSec)),
          const SizedBox(height: 16),
          _contactRow(context, Icons.email_outlined, 'Email', 'support@flowcrm.com',
              AppColors.primary, 'support@flowcrm.com'),
          const SizedBox(height: 8),
          _contactRow(context, Icons.chat_bubble_outline, 'Live Chat',
              'Available Mon–Sat, 9am–6pm IST', AppColors.success, null),
          const SizedBox(height: 8),
          _contactRow(context, Icons.phone_outlined, 'Phone', '+91 98765 43210',
              AppColors.info, '+919876543210'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Average response time: under 2 hours',
                style: TextStyle(fontSize: 11, color: AppColors.success),
                textAlign: TextAlign.center),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _contactRow(BuildContext context, IconData icon, String label, String value,
      Color color, String? copyText) =>
      Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textGhost)),
          Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ])),
        if (copyText != null)
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 16, color: AppColors.textGhost),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: copyText));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('$label copied'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ));
            },
          ),
      ]);

  // ── Rate the App ───────────────────────────────────────────────
  void _showRateApp(BuildContext context) {
    int stars = 0;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Rate FlowCRM',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Enjoying the app? Share your experience!',
                style: TextStyle(fontSize: 13, color: AppColors.textSec),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => stars = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 38,
                    color: AppColors.warning,
                  ),
                ),
              )),
            ),
            if (stars > 0) ...[
              const SizedBox(height: 12),
              Text(
                stars >= 4
                    ? '🎉 Awesome! Thank you for your support!'
                    : stars >= 3
                        ? 'Thanks for your feedback!'
                        : 'We\'re sorry to hear that. We\'ll improve!',
                style: TextStyle(
                    fontSize: 12,
                    color: stars >= 4 ? AppColors.success : AppColors.textSec,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not Now')),
            if (stars > 0)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Thank you for your $stars-star review!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning, foregroundColor: Colors.white),
                child: const Text('Submit'),
              ),
          ],
        ),
      ),
    );
  }

  // ── About FlowCRM ──────────────────────────────────────────────
  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
                gradient: AppColors.gradient, borderRadius: BorderRadius.circular(16)),
            child: const Center(
              child: Text('FC',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 12),
          const Text('FlowCRM',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const Text('v1.0.0',
              style: TextStyle(fontSize: 12, color: AppColors.textGhost)),
          const SizedBox(height: 8),
          const Text('Business management for every industry',
              style: TextStyle(fontSize: 12, color: AppColors.textSec),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _infoRow(Icons.business_outlined,    'Built for Indian businesses',   AppColors.primary),
          _infoRow(Icons.lock_outline,          'Secure & encrypted data',       AppColors.success),
          _infoRow(Icons.devices_outlined,      'Android & iOS supported',       AppColors.info),
          _infoRow(Icons.support_agent_outlined,'24/7 support available',        AppColors.warning),
          const SizedBox(height: 12),
          const Text('© 2024 FlowCRM. All rights reserved.',
              style: TextStyle(fontSize: 10, color: AppColors.textGhost),
              textAlign: TextAlign.center),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSec)),
    ]),
  );

  // ── Change Password ────────────────────────────────────────────
  void _showChangePassword(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }
}

// ── Change-password dialog widget (needs its own State for controllers) ──────
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentCtrl  = TextEditingController();
  final _newCtrl      = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscureCur  = true;
  bool _obscureNew  = true;
  bool _obscureCon  = true;
  bool _loading     = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text.trim();
    final newPass  = _newCtrl.text;
    final confirm  = _confirmCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (!newPass.contains(RegExp(r'[A-Z]'))) {
      setState(() => _error = 'Include at least one uppercase letter.');
      return;
    }
    if (!newPass.contains(RegExp(r'[0-9]'))) {
      setState(() => _error = 'Include at least one number.');
      return;
    }
    if (!newPass.contains(RegExp(r'[^A-Za-z0-9]'))) {
      setState(() => _error = 'Include at least one special character.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient().changePassword(
        currentPassword: current,
        newPassword:     newPass,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
        content: Text('Password changed successfully'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _loading = false;
        _error = msg.contains('401') || msg.contains('incorrect') || msg.contains('wrong')
            ? 'Current password is incorrect.'
            : 'Failed to change password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.danger)),
            ),
          _passField('Current Password', _currentCtrl, _obscureCur,
              () => setState(() => _obscureCur = !_obscureCur)),
          const SizedBox(height: 12),
          _passField('New Password', _newCtrl, _obscureNew,
              () => setState(() => _obscureNew = !_obscureNew)),
          const SizedBox(height: 12),
          _passField('Confirm New Password', _confirmCtrl, _obscureCon,
              () => setState(() => _obscureCon = !_obscureCon)),
          const SizedBox(height: 8),
          const Text('Min 8 chars · uppercase · number · special character',
              style: TextStyle(fontSize: 10, color: AppColors.textGhost)),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Change'),
        ),
      ],
    );
  }

  Widget _passField(String label, TextEditingController ctrl, bool obscure,
      VoidCallback toggle) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: AppColors.textGhost,
            ),
            onPressed: toggle,
          ),
        ),
      );
}
