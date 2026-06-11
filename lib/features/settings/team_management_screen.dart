import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/services/api_client.dart';
import '../../shared/widgets/empty_state.dart';

final _teamProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await ApiClient().getTeamMembers();
  final raw = res.data['data'];
  return raw is List ? raw : (raw?['members'] as List? ?? []);
});

class TeamManagementScreen extends ConsumerWidget {
  const TeamManagementScreen({super.key});

  Color _roleColor(String? role) {
    switch (role?.toUpperCase()) {
      case 'OWNER':   return AppColors.danger;
      case 'ADMIN':   return AppColors.primary;
      case 'MANAGER': return AppColors.warning;
      default:        return AppColors.textSec;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(_teamProvider);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Team Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Invite Member',
            onPressed: () => _inviteDialog(context, ref),
          ),
        ],
      ),
      body: team.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error:   (e, _) => EmptyState(
          icon: Icons.people_outline,
          message: 'Unable to load team',
          subtitle: 'Check your connection and try again',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(_teamProvider),
        ),
        data: (members) => members.isEmpty
            ? EmptyState(
                icon: Icons.group_outlined,
                message: 'No team members yet',
                subtitle: 'Invite your team to collaborate',
                actionLabel: 'Invite Member',
                onAction: () => _inviteDialog(context, ref),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: members.length,
                itemBuilder: (_, i) {
                  final m    = members[i] as Map<String, dynamic>;
                  final role = m['role'] as String? ?? 'MEMBER';
                  final rc   = _roleColor(role);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          (m['name'] as String? ?? m['user']?['name'] as String? ?? 'M').isNotEmpty
                              ? (m['name'] as String? ?? m['user']?['name'] as String? ?? 'M')[0].toUpperCase()
                              : 'M',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                      title: Text(
                        m['name'] as String? ?? m['user']?['name'] as String? ?? 'Member',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        m['email'] as String? ?? m['user']?['email'] as String? ?? '',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGhost),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: rc.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: rc)),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _inviteDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_outlined, color: Colors.white),
        label: const Text('Invite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _inviteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _InviteDialog(
        onInvited: () => ref.invalidate(_teamProvider),
      ),
    );
  }
}

// ── Invite dialog (needs its own State for the loading indicator) ─────────────
class _InviteDialog extends StatefulWidget {
  final VoidCallback onInvited;
  const _InviteDialog({required this.onInvited});
  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _emailCtrl = TextEditingController();
  String _role     = 'MEMBER';
  bool _loading    = false;
  String? _error;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient().inviteMember(email, role: _role);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      widget.onInvited();
      messenger.showSnackBar(SnackBar(
        content: Text('Invitation sent to $email'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _loading = false;
        _error   = msg.contains('already') ? 'This person is already a member or was invited.'
                 : msg.contains('404')     ? 'No account found with this email.'
                 : 'Failed to send invite. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite Team Member',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          ),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loading ? null : _send(),
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined, size: 18, color: AppColors.textGhost),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _role,
          decoration: const InputDecoration(
            labelText: 'Role',
            prefixIcon: Icon(Icons.badge_outlined, size: 18, color: AppColors.textGhost),
          ),
          items: const [
            DropdownMenuItem(value: 'MEMBER',  child: Text('Member')),
            DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
            DropdownMenuItem(value: 'ADMIN',   child: Text('Admin')),
          ],
          onChanged: (v) => setState(() => _role = v!),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _send,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Send Invite'),
        ),
      ],
    );
  }
}
