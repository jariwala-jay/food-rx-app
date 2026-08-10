import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/widgets/zoomable_asset_image.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';

class ScreenshotViewerWidget extends StatefulWidget {
  final String planType;
  final String title;
  final bool showGlycemicIndex;

  const ScreenshotViewerWidget({
    Key? key,
    required this.planType,
    required this.title,
    this.showGlycemicIndex = false,
  }) : super(key: key);

  @override
  State<ScreenshotViewerWidget> createState() => _ScreenshotViewerWidgetState();
}

class _ScreenshotViewerWidgetState extends State<ScreenshotViewerWidget> {
  int _currentPage = 0;
  List<String> _imagePaths = [];
  bool _isLoading = true;
  bool _isCurrentPageZoomed = false;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<List<String>> _loadImagesFromFolder(
      String folderPath, String planName) async {
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

    return imagePaths;
  }

  void _loadImages() async {
    // First, load images from the main plan type
    String mainFolderPath = _getFolderPath(widget.planType);
    List<String> mainImages =
        await _loadImagesFromFolder(mainFolderPath, widget.planType);

    // Exclude 8.png and 9.png for MyPlate (shown on Portion Size Details page)
    if (widget.planType == 'MyPlate') {
      mainImages = mainImages
          .where((path) => !path.endsWith('8.png') && !path.endsWith('9.png'))
          .toList();
    }

    // For Diabetes Plate \"My Plan\", only show 1–6 and 9 (skip 7 & 8),
    // then append glycemic index images (if enabled) below.
    if (widget.planType == 'DiabetesPlate') {
      const keepSuffixes = [
        '1.png',
        '2.png',
        '3.png',
        '4.png',
        '5.png',
        '6.png',
        '9.png',
      ];
      mainImages = mainImages
          .where((path) => keepSuffixes.any((s) => path.endsWith(s)))
          .toList();
    }

    // Then, if showGlycemicIndex is true, load glycemic index images
    List<String> glycemicImages = [];
    if (widget.showGlycemicIndex && widget.planType != 'GlycemicIndex') {
      String glycemicFolderPath = _getFolderPath('GlycemicIndex');
      glycemicImages =
          await _loadImagesFromFolder(glycemicFolderPath, 'GlycemicIndex');
    }

    setState(() {
      _imagePaths = [...mainImages, ...glycemicImages];
      _isLoading = false;
    });
  }

  String _getFolderPath(String planType) {
    switch (planType) {
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
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      // A freshly swiped-to page always starts at its default zoom.
      _isCurrentPageZoomed = false;
    });
  }

  Widget _buildImageError(String assetPath) {
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
          const Text(
            'Image not found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            assetPath,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
        ),
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
              'Please add screenshots to ${_getFolderPath(widget.planType)}',
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
        // Image viewer (pinch to zoom)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                ZoomableAssetImage.pinchToZoomHint,
                const SizedBox(height: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _imagePaths.length,
                      onPageChanged: _onPageChanged,
                      // While the current page is pinch-zoomed, hand control
                      // fully to ZoomableAssetImage's own pan handling so a
                      // one-finger drag doesn't get mistaken for a swipe.
                      physics: _isCurrentPageZoomed
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),
                      itemBuilder: (context, index) {
                        final assetPath = _imagePaths[index];
                        return ZoomableAssetImage(
                          assetPath: assetPath,
                          onZoomChanged: index == _currentPage
                              ? (isZoomed) {
                                  if (isZoomed != _isCurrentPageZoomed) {
                                    setState(
                                        () => _isCurrentPageZoomed = isZoomed);
                                  }
                                }
                              : null,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildImageError(assetPath),
                        );
                      },
                    ),
                  ),
                ),
              ],
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
                          } catch (e) {
                            // Silently handle error
                          }
                        });
                      } else if (isLastPage && !isTourActive) {
                        // Just go back to home when tour is not active
                        Navigator.of(context).pop();
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
                    child: Text(isLastPage && isTourActive
                        ? 'Continue Tour'
                        : isLastPage
                            ? 'Done'
                            : 'Next'),
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
