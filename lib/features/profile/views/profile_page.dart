import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'package:flutter_app/core/utils/user_facing_errors.dart';
import 'package:flutter_app/features/profile/views/profile_edit_page.dart';
import 'package:flutter_app/features/profile/views/notification_preferences_page.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_app/core/utils/image_crop_helper.dart';

enum _PhotoAction { gallery, camera, remove }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Uint8List? _profilePhotoData;
  final _imagePicker = ImagePicker();
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadProfilePhoto();
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
    } else if (mounted) {
      setState(() {
        _profilePhotoData = authProvider.localProfilePhotoData;
      });
    }
  }

  Future<void> _pickAndUpdateProfilePhoto() async {
    try {
      final _PhotoAction? action = await showModalBottomSheet<_PhotoAction>(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, _PhotoAction.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, _PhotoAction.camera),
              ),
              if (_profilePhotoData != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove Photo',
                      style: TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pop(context, _PhotoAction.remove),
                ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );

      if (action == null) return;

      if (action == _PhotoAction.remove) {
        await _removeProfilePhoto();
        return;
      }

      // Wait for the bottom sheet route to finish closing before presenting the
      // system picker; opening PHPicker immediately after pop can hang on iOS.
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;

      final pickedFile = await _imagePicker.pickImage(
        source: action == _PhotoAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (pickedFile != null && mounted) {
        final croppedFile = await cropProfilePhoto(context, pickedFile.path);
        if (croppedFile == null || !mounted) return;

        setState(() {
          _isUploadingPhoto = true;
        });

        final authController = context.read<AuthController>();

        authController.clearError();
        await authController.updateProfilePhoto(croppedFile);

        if (mounted) {
          final error = authController.error;
          if (error != null) {
            setState(() {
              _isUploadingPhoto = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          await _loadProfilePhoto();

          setState(() {
            _isUploadingPhoto = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile photo updated successfully'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    setState(() {
      _isUploadingPhoto = true;
    });

    final authController = context.read<AuthController>();
    authController.clearError();
    await authController.removeProfilePhoto();

    if (!mounted) return;

    final error = authController.error;
    if (error != null) {
      setState(() {
        _isUploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _profilePhotoData = null;
      _isUploadingPhoto = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile photo removed'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getPlanDisplayName(UserModel user) {
    final myPlan = user.myPlanType ?? user.dietType ?? 'MyPlate';
    String planName;
    switch (myPlan) {
      case 'DiabetesPlate':
        planName = 'Diabetes Plate (ADA)';
        break;
      case 'DASH':
        planName = 'DASH Diet';
        break;
      case 'MyPlate':
        planName = 'MyPlate Nutrition';
        break;
      default:
        planName = myPlan;
    }
    return planName;
  }

  String _formatHeight(UserModel user) {
    if (user.heightUnit == 'inches' || user.heightUnit == null) {
      if (user.heightFeet != null && user.heightInches != null) {
        return "${user.heightFeet!.toInt()}'${user.heightInches!.toInt()}\"";
      } else if (user.height != null) {
        final inches = user.height!;
        final feet = (inches / 12).floor();
        final remainingInches = (inches % 12).round();
        return "$feet'$remainingInches\"";
      }
    } else if (user.heightUnit == 'cm') {
      if (user.height != null) {
        return "${user.height!.toStringAsFixed(0)} cm";
      }
    }
    return 'Not set';
  }

  String _formatWeight(UserModel user) {
    if (user.weight != null) {
      final unit = user.weightUnit ?? 'lbs';
      final weight =
          user.weight!.toStringAsFixed(user.weight! % 1 == 0 ? 0 : 1);
      return '$weight $unit';
    }
    return 'Not set';
  }

  int? _calculateAge(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  String _formatDateOfBirth(DateTime? dob) {
    if (dob == null) return 'Not set';
    return DateFormat('MM/dd/yyyy').format(dob);
  }

  String _formatSex(String? sex) {
    if (sex == null) return 'Not set';
    switch (sex.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'intersex':
        return 'Intersex';
      default:
        return sex;
    }
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        const brand = Color(0xFFFF6A00);
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to log out?',
                  style: TextStyle(fontSize: 16, color: Color(0xFF444444)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5F5F6E),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Log Out'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true && context.mounted) {
      final authController = context.read<AuthController>();
      await authController.logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Consumer<AuthController>(
        builder: (context, authController, child) {
          final user = authController.currentUser;
          if (user == null) {
            return const Center(
              child: Text('Please log in to view your profile'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _loadProfilePhoto();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: _profilePhotoData != null
                                  ? MemoryImage(_profilePhotoData!)
                                  : const AssetImage(
                                          'assets/images/profile_pic.png')
                                      as ImageProvider,
                            ),
                            if (_isUploadingPhoto)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickAndUpdateProfilePhoto,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6A00),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.name ?? 'User',
                          style: AppTypography.bg_24_b,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.email,
                          style: AppTypography.bg_16_r.copyWith(
                            color: const Color(0xFF90909A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6A00),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Meal Plan',
                            style: AppTypography.bg_14_r.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getPlanDisplayName(user),
                            style: AppTypography.bg_20_b.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context: context,
                    title: 'Personal Information',
                    children: [
                      _buildInfoRow(
                        context: context,
                        label: 'Name',
                        value: user.name ?? 'Not set',
                        onTap: () => _navigateToEditField(
                          context,
                          'name',
                          user.name,
                        ),
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        context: context,
                        label: 'Email',
                        value: user.email,
                        onTap: () => _navigateToEditField(
                          context,
                          'email',
                          user.email,
                        ),
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        context: context,
                        label: 'Date of Birth',
                        value: user.dateOfBirth != null
                            ? '${_formatDateOfBirth(user.dateOfBirth)} (Age: ${_calculateAge(user.dateOfBirth) ?? 'N/A'})'
                            : 'Not set',
                        onTap: () => _navigateToEditField(
                          context,
                          'dateOfBirth',
                          user.dateOfBirth,
                        ),
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        context: context,
                        label: 'Sex',
                        value: _formatSex(user.sex),
                        onTap: () => _navigateToEditField(
                          context,
                          'sex',
                          user.sex,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    context: context,
                    title: 'Physical Information',
                    children: [
                      _buildInfoRow(
                        context: context,
                        label: 'Height',
                        value: _formatHeight(user),
                        onTap: () => _navigateToEditField(
                          context,
                          'height',
                          {
                            'heightFeet': user.heightFeet,
                            'heightInches': user.heightInches,
                            'height': user.height,
                            'heightUnit': user.heightUnit,
                          },
                        ),
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        context: context,
                        label: 'Weight',
                        value: _formatWeight(user),
                        onTap: () => _navigateToEditField(
                          context,
                          'weight',
                          {
                            'weight': user.weight,
                            'weightUnit': user.weightUnit,
                          },
                        ),
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        context: context,
                        label: 'Activity Level',
                        value: user.activityLevel ?? 'Not set',
                        onTap: () => _navigateToEditField(
                          context,
                          'activityLevel',
                          user.activityLevel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    context: context,
                    title: 'Diet-related Health Goals',
                    children: [
                      InkWell(
                        onTap: () => _navigateToEditField(
                          context,
                          'healthGoals',
                          user.healthGoals,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Diet-related Health Goals',
                                      style: AppTypography.bg_16_m,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF90909A),
                                  ),
                                ],
                              ),
                              if (user.healthGoals.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: user.healthGoals
                                      .map((goal) => Chip(
                                            label: Text(goal),
                                            backgroundColor:
                                                const Color(0xFFFFEFE7),
                                            labelStyle: const TextStyle(
                                              color: Color(0xFFFF6A00),
                                              fontSize: 12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 0),
                                          ))
                                      .toList(),
                                ),
                              ] else
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Not set',
                                    style: AppTypography.bg_14_r.copyWith(
                                      color: const Color(0xFF90909A),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    context: context,
                    title: 'Medical Information',
                    children: [
                      InkWell(
                        onTap: () => _navigateToEditField(
                          context,
                          'medicalConditions',
                          user.medicalConditions ?? [],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Diet-related Chronic Condition',
                                      style: AppTypography.bg_16_m,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF90909A),
                                  ),
                                ],
                              ),
                              if (user.medicalConditions != null &&
                                  user.medicalConditions!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: user.medicalConditions!
                                      .map((condition) => Chip(
                                            label: Text(condition),
                                            backgroundColor:
                                                const Color(0xFFFFEFE7),
                                            labelStyle: const TextStyle(
                                              color: Color(0xFFFF6A00),
                                              fontSize: 12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 0),
                                          ))
                                      .toList(),
                                ),
                              ] else
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Not set',
                                    style: AppTypography.bg_14_r.copyWith(
                                      color: const Color(0xFF90909A),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      _buildDivider(),
                      InkWell(
                        onTap: () => _navigateToEditField(
                          context,
                          'allergies',
                          user.allergies ?? [],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Food Allergies & Intolerances',
                                      style: AppTypography.bg_16_m,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF90909A),
                                  ),
                                ],
                              ),
                              if ((user.allergies?.isNotEmpty ?? false) ||
                                  (user.excludedIngredients?.isNotEmpty ??
                                      false)) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...?user.allergies,
                                    ...?user.excludedIngredients
                                        ?.map((item) => item.displayName),
                                  ]
                                      .map((allergy) => Chip(
                                            label: Text(allergy),
                                            backgroundColor:
                                                const Color(0xFFFFEFE7),
                                            labelStyle: const TextStyle(
                                              color: Color(0xFFFF6A00),
                                              fontSize: 12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 0),
                                          ))
                                      .toList(),
                                ),
                              ] else
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Not set',
                                    style: AppTypography.bg_14_r.copyWith(
                                      color: const Color(0xFF90909A),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    context: context,
                    title: 'Settings',
                    children: [
                      _buildInfoRow(
                        context: context,
                        label: 'Notification Preferences',
                        value: '',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NotificationPreferencesPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(),
                      _buildInfoRow(
                        context: context,
                        label: 'Privacy Policy',
                        value: '',
                        onTap: () {
                          // TODO: Implement privacy policy view
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Privacy Policy coming soon'),
                            ),
                          );
                        },
                      ),
                      _buildDivider(),
                      _BiometricToggleRow(onChanged: () => setState(() {})),
                      _buildDivider(),
                      _buildInfoRow(
                        context: context,
                        label: 'Log Out',
                        value: '',
                        textColor: Colors.red,
                        onTap: () => _showLogoutConfirmation(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: AppTypography.bg_18_b,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required String label,
    required String value,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bg_16_m,
                  ),
                  if (value.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: AppTypography.bg_14_r.copyWith(
                        color: textColor ?? const Color(0xFF90909A),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF90909A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFE7E9EC),
    );
  }

  void _navigateToEditField(
    BuildContext context,
    String fieldType,
    dynamic currentValue,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditPage(
          fieldType: fieldType,
          currentValue: currentValue,
        ),
      ),
    );
  }
}

// ── Biometric toggle row ────────────────────────────────────────────────────

class _BiometricToggleRow extends StatefulWidget {
  final VoidCallback onChanged;

  const _BiometricToggleRow({required this.onChanged});

  @override
  State<_BiometricToggleRow> createState() => _BiometricToggleRowState();
}

class _BiometricToggleRowState extends State<_BiometricToggleRow> {
  bool? _isEnabled;
  bool _isSupported = false;
  String _label = 'Sign in with Face ID / Fingerprint';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final supported = await auth.canUseBiometricLogin();
    final enabled = await auth.isBiometricEnabled();
    String label = 'Sign in with Face ID / Fingerprint';
    if (supported) {
      final labels = await auth.getBiometricSignInLabels();
      label = labels.saveLoginCheckbox;
    }
    if (!mounted) return;
    setState(() {
      _isSupported = supported;
      _isEnabled = enabled;
      _label = label;
    });
  }

  Future<void> _toggle(bool value) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    final auth = context.read<AuthController>();

    if (value) {
      final ok = await auth.enableBiometricLogin();
      if (mounted) {
        setState(() {
          _isEnabled = ok ? true : _isEnabled;
          _isBusy = false;
        });
        if (!ok && auth.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(auth.error!)),
          );
        } else if (ok) {
          widget.onChanged();
        }
      }
    } else {
      await _confirmDisable(auth);
    }
  }

  Future<void> _confirmDisable(AuthController auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Turn off biometric sign-in?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "You'll need to sign in manually next time.",
                style: TextStyle(fontSize: 15, color: Color(0xFF444444)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5F5F6E),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6A00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Turn off'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await auth.disableBiometricLogin();
      setState(() {
        _isEnabled = false;
        _isBusy = false;
      });
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric sign-in turned off')),
        );
      }
    } else if (mounted) {
      setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported || _isEnabled == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isEnabled!
                      ? 'Sign in without a password'
                      : 'Enable for faster sign-in',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF90909A),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isEnabled!,
            onChanged: _isBusy ? null : _toggle,
            activeColor: const Color(0xFFFF6A00),
          ),
        ],
      ),
    );
  }
}
