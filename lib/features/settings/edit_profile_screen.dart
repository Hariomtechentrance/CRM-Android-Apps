import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../shared/widgets/fc_button.dart';
import '../../data/services/api_client.dart';
import '../auth/auth_notifier.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  bool _uploadingPhoto = false;
  File? _localPhoto;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).valueOrNull?.user;
    _nameCtrl.text  = user?.name  ?? '';
    _phoneCtrl.text = user?.phone ?? '';
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 400,
      maxHeight: 400,
    );
    if (image == null || !mounted) return;

    setState(() { _uploadingPhoto = true; _localPhoto = File(image.path); });
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(image.path, filename: 'avatar.jpg'),
      });
      final res = await ApiClient().uploadAvatar(formData);
      final avatarUrl = (res.data['data'] as Map<String, dynamic>?)?['avatarUrl'] as String?;
      if (avatarUrl != null) {
        await ref.read(authNotifierProvider.notifier).updateLocalProfile(avatar: avatarUrl);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile photo updated'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _localPhoto = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to upload photo. Please try again.'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiClient().updateProfile({
        'name':  _nameCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      });
      await ref.read(authNotifierProvider.notifier).updateLocalProfile(
        name:  _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile updated'), backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to update profile'), backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull?.user;
    final avatarUrl = user?.avatar;
    final initials = (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Stack(children: [
              GestureDetector(
                onTap: _uploadingPhoto ? null : _pickPhoto,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: _localPhoto != null
                      ? FileImage(_localPhoto!)
                      : (avatarUrl != null ? NetworkImage(avatarUrl) as ImageProvider : null),
                  child: (_localPhoto == null && avatarUrl == null)
                      ? Text(initials, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.primary))
                      : null,
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _uploadingPhoto ? null : _pickPhoto,
                  child: Container(
                    width: 28, height: 28,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: _uploadingPhoto
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt_outlined, size: 15, color: Colors.white),
                  ),
                ),
              ),
            ])),
            const SizedBox(height: 8),
            const Center(child: Text('Tap photo to change', style: TextStyle(fontSize: 11, color: AppColors.textGhost))),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person_outlined, size: 18, color: AppColors.textGhost),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              enabled: false,
              initialValue: user?.email ?? '',
              decoration: const InputDecoration(
                labelText: 'Email (cannot change)',
                prefixIcon: Icon(Icons.email_outlined, size: 18, color: AppColors.textGhost),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined, size: 18, color: AppColors.textGhost),
              ),
            ),
            const SizedBox(height: 28),
            FCButton(label: 'Save Changes', loading: _loading, onPressed: _submit, icon: Icons.save_outlined),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}
