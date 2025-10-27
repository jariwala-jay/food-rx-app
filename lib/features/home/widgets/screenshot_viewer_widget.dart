import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';

class ScreenshotViewerWidget extends StatefulWidget {
  final String planType;
  final String title;

  const ScreenshotViewerWidget({
    Key? key,
    required this.planType,
    required this.title,
  }) : super(key: key);

  @override
  State<ScreenshotViewerWidget> createState() => _ScreenshotViewerWidgetState();
}

class _ScreenshotViewerWidgetState extends State<ScreenshotViewerWidget> {
  int _currentPage = 0;
  List<String> _imagePaths = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  void _loadImages() async {
    // Get the folder path based on plan type
    String folderPath = _getFolderPath();

    List<String> imagePaths = [];
    int pageNumber = 1;

    // Dynamically check for images starting from 1.png, 2.png, etc.
    while (true) {
      String imagePath = '$folderPath$pageNumber.png';
      try {
        // Try to load the asset to see if it exists
        await rootBundle.load(imagePath);
        imagePaths.add(imagePath);
        pageNumber++;
      } catch (e) {
        // Asset doesn't exist, stop looking
        break;
      }
    }

    setState(() {
      _imagePaths = imagePaths;
      _isLoading = false;
    });
  }

  String _getFolderPath() {
    switch (widget.planType) {
      case 'DASH':
        return 'assets/nutrition/screenshots/dash/';
      case 'MyPlate':
        return 'assets/nutrition/screenshots/myplate/';
      case 'DiabetesPlate':
        return 'assets/nutrition/screenshots/diabetes_plate/';
      case 'GlycemicIndex':
        return 'assets/nutrition/screenshots/glycemic_index/';
      default:
        return 'assets/nutrition/screenshots/myplate/';
    }
  }

  void _nextPage() {
    if (_currentPage < _imagePaths.length - 1) {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_imagePaths.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_not_supported,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No images available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please add screenshots to ${_getFolderPath()}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Image viewer
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                _imagePaths[_currentPage],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Image not found',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _imagePaths[_currentPage],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Navigation buttons
        Consumer<ForcedTourProvider>(
          builder: (context, tourProvider, child) {
            final isLastPage = _currentPage >= _imagePaths.length - 1;
            final isTourActive = tourProvider.isTourActive;

            return Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _currentPage > 0 ? _previousPage : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Previous'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (isLastPage && isTourActive) {
                        // Complete the diet plan step and go back to home
                        tourProvider.completeCurrentStep();
                        Navigator.of(context).pop();

                        // Trigger the next showcase step (Add Button) after navigation
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          try {
                            ShowcaseView.get()
                                .startShowCase([TourKeys.addButtonKey]);
                            print(
                                '🎯 ScreenshotViewer: Triggered Add Button showcase after diet plan');
                          } catch (e) {
                            print(
                                '🎯 ScreenshotViewer: Error triggering Add Button showcase: $e');
                          }
                        });
                      } else if (!isLastPage) {
                        _nextPage();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                        isLastPage && isTourActive ? 'Continue Tour' : 'Next'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
