import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'package:flutter_app/features/tracking/controller/tracker_provider.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';

class PersonalizedDietSummary extends StatelessWidget {
  final String dietType;
  final int targetCalories;
  final Map<String, dynamic> selectedDietPlan;
  final Map<String, dynamic> diagnostics;
  final VoidCallback onFinish;

  const PersonalizedDietSummary({
    Key? key,
    required this.dietType,
    required this.targetCalories,
    required this.selectedDietPlan,
    required this.diagnostics,
    required this.onFinish,
  }) : super(key: key);

  Future<void> _handleContinue(BuildContext context) async {
    try {
      // Get the current user
      final authProvider = Provider.of<AuthController>(context, listen: false);
      final user = authProvider.currentUser;

      if (user != null && user.id != null) {
        // Create personalized trackers
        final trackerProvider =
            Provider.of<TrackerProvider>(context, listen: false);
        await trackerProvider.updateTrackersWithPersonalizedPlan(
          user.id!,
          dietType,
          selectedDietPlan,
        );
      }
    } catch (e) {
      // Error creating personalized trackers during signup
    }

    // Continue to the app
    onFinish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Your Personalized Diet Plan',
                  style: AppTypography.bg_28_b.copyWith(
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on your health profile, we\'ve created a customized nutrition plan just for you.',
                  style: AppTypography.bg_16_r.copyWith(
                    color: const Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 32),

                // Diet Type Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: dietType == 'DASH'
                        ? const Color(0xFFE8F5E8)
                        : const Color(0xFFE8F4FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: dietType == 'DASH'
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF2196F3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            dietType == 'DASH'
                                ? Icons.favorite
                                : Icons.restaurant,
                            color: dietType == 'DASH'
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF2196F3),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            dietType == 'DASH'
                                ? 'DASH Diet'
                                : 'MyPlate Guidelines',
                            style: AppTypography.bg_20_sb.copyWith(
                              color: dietType == 'DASH'
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF2196F3),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dietType == 'DASH'
                            ? 'Designed to help lower blood pressure and improve heart health.'
                            : 'Balanced nutrition approach for overall health and wellness.',
                        style: AppTypography.bg_14_r.copyWith(
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Calorie Target
                _buildInfoCard(
                  'Daily Calorie Target',
                  '$targetCalories calories',
                  Icons.local_fire_department,
                  const Color(0xFFFF9800),
                ),
                const SizedBox(height: 16),

                // Daily Targets
                if (dietType == 'DASH')
                  _buildDashTargets()
                else
                  _buildMyPlateTargets(),

                const SizedBox(height: 32),

                // Diagnostics Info
                if (diagnostics.isNotEmpty) ...[
                  Text(
                    'Plan Details',
                    style: AppTypography.bg_20_sb.copyWith(
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: diagnostics.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDiagnosticKey(entry.key),
                                style: AppTypography.bg_14_r.copyWith(
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              Text(
                                _formatDiagnosticValue(entry.value),
                                style: AppTypography.bg_14_r.copyWith(
                                  color: const Color(0xFF1A1A1A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleContinue(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Continue to App',
                      style: AppTypography.bg_16_sb.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bg_14_r.copyWith(
                    color: const Color(0xFF666666),
                  ),
                ),
                Text(
                  value,
                  style: AppTypography.bg_20_sb.copyWith(
                    color: const Color(0xFF1A1A1A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashTargets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Servings',
          style: AppTypography.bg_20_sb.copyWith(
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(
            children: [
              _buildTargetRow(
                  'Grains', selectedDietPlan['grains']?.toString() ?? 'N/A'),
              _buildTargetRow('Vegetables',
                  selectedDietPlan['vegetables']?.toString() ?? 'N/A'),
              _buildTargetRow(
                  'Fruits', selectedDietPlan['fruits']?.toString() ?? 'N/A'),
              _buildTargetRow(
                  'Dairy', selectedDietPlan['dairy']?.toString() ?? 'N/A'),
              _buildTargetRow('Lean Meats',
                  selectedDietPlan['leanMeats']?.toString() ?? 'N/A'),
              _buildTargetRow(
                  'Oils', selectedDietPlan['oils']?.toString() ?? 'N/A'),
              _buildTargetRow(
                  'Sodium', '${selectedDietPlan['sodium'] ?? 'N/A'} mg'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyPlateTargets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Targets',
          style: AppTypography.bg_20_sb.copyWith(
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(
            children: [
              _buildTargetRow(
                  'Fruits', '${selectedDietPlan['fruits'] ?? 'N/A'} cups'),
              _buildTargetRow('Vegetables',
                  '${selectedDietPlan['vegetables'] ?? 'N/A'} cups'),
              _buildTargetRow(
                  'Grains', '${selectedDietPlan['grains'] ?? 'N/A'} oz'),
              _buildTargetRow(
                  'Protein', '${selectedDietPlan['protein'] ?? 'N/A'} oz'),
              _buildTargetRow(
                  'Dairy', '${selectedDietPlan['dairy'] ?? 'N/A'} cups'),
              _buildTargetRow('Added Sugars',
                  '≤${selectedDietPlan['addedSugarsMax'] ?? 'N/A'} g'),
              _buildTargetRow('Saturated Fat',
                  '≤${selectedDietPlan['saturatedFatMax'] ?? 'N/A'} g'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTargetRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bg_14_r.copyWith(
              color: const Color(0xFF666666),
            ),
          ),
          Text(
            value,
            style: AppTypography.bg_14_r.copyWith(
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDiagnosticKey(String key) {
    switch (key) {
      case 'bmr':
        return 'Basal Metabolic Rate';
      case 'pal':
        return 'Physical Activity Level';
      case 'tdee':
        return 'Total Daily Energy Expenditure';
      case 'maintenance':
        return 'Maintenance Calories';
      case 'tier':
        return 'Calorie Tier';
      case 'mode':
        return 'Weight Management Mode';
      default:
        return key;
    }
  }

  String _formatDiagnosticValue(dynamic value) {
    if (value is double) {
      return value.toStringAsFixed(1);
    }
    return value.toString();
  }
}
