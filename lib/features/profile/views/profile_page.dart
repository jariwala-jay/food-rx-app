import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'dart:typed_data';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  Uint8List? _profilePhotoData;

  @override
  void initState() {
    super.initState();
    final authController = context.read<AuthController>();
    _nameController.text = authController.currentUser?.name ?? '';
    _emailController.text = authController.currentUser?.email ?? '';
    _loadProfilePhoto();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfilePhoto() async {
    final authProvider = Provider.of<AuthController>(context, listen: false);
    if (authProvider.currentUser?.profilePhotoId != null) {
      final photoData = await authProvider.getProfilePhoto();
      if (mounted && photoData != null) {
        setState(() {
          _profilePhotoData = Uint8List.fromList(photoData);
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      final authController = context.read<AuthController>();
      final updates = {
        'name': _nameController.text,
        'email': _emailController.text,
      };
      await authController.updateUserProfile(updates);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authController.logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: _profilePhotoData != null
                    ? MemoryImage(_profilePhotoData!)
                    : const AssetImage('assets/images/profile_pic.png')
                        as ImageProvider,
              ),
              const SizedBox(height: 24),
              AppFormField(
                label: 'Name',
                hintText: 'Enter your name',
                controller: _nameController,
              ),
              const SizedBox(height: 16),
              AppFormField(
                label: 'Email',
                hintText: 'Enter your email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child:
                      const Text('Save Changes', style: AppTypography.bg_16_sb),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
