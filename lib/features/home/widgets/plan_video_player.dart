import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Helper class to hold video source information
class _VideoSource {
  final String path;
  final bool isNetwork;

  _VideoSource({required this.path, required this.isNetwork});
}

class PlanVideoPlayer extends StatefulWidget {
  final String planType;
  final String title;
  final bool isTourActive;

  const PlanVideoPlayer({
    Key? key,
    required this.planType,
    required this.title,
    required this.isTourActive,
  }) : super(key: key);

  @override
  State<PlanVideoPlayer> createState() => _PlanVideoPlayerState();
}

class _PlanVideoPlayerState extends State<PlanVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isVideoCompleted = false;
  bool _isVideoInitialized = false;
  String? _errorMessage;

  // Check if video watching is mandatory from env var
  bool get _isMandatoryVideo =>
      dotenv.env['MANDATORY_PLAN_VIDEO']?.toLowerCase() == 'true';

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final videoSource = _getVideoSource(widget.planType);

      // Create controller based on source type (network URL or local asset)
      if (videoSource.isNetwork) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(videoSource.path),
        );
      } else {
        _controller = VideoPlayerController.asset(videoSource.path);
      }

      await _controller!.initialize();

      // Listen for video completion and position updates
      _controller!.addListener(() {
        if (mounted) {
          _checkVideoCompletion();
          setState(() {}); // Update UI for progress bar
        }
      });

      setState(() {
        _isLoading = false;
        _isVideoInitialized = true;
      });

      // Start playing automatically
      _controller!.play();
    } catch (e) {
      debugPrint('Error initializing video: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        // Provide helpful error message
        if (e.toString().contains('not configured')) {
          _errorMessage = e.toString();
        } else {
          _errorMessage = 'Failed to load video from cloud storage.\n\n'
              'Please check:\n'
              '1. Video URL is correctly set in .env file\n'
              '2. Firebase Storage rules allow public read access\n'
              '3. Internet connection is available\n\n'
              'Error: $e';
        }
      });
    }
  }

  void _checkVideoCompletion() {
    if (_controller != null && _controller!.value.isInitialized) {
      final position = _controller!.value.position;
      final duration = _controller!.value.duration;

      // Check if video has reached the end (with 500ms tolerance for timing precision)
      if (duration.inMilliseconds > 0) {
        final positionMs = position.inMilliseconds;
        final durationMs = duration.inMilliseconds;
        final remaining = durationMs - positionMs;

        // Consider complete if:
        // 1. Position is at or very close to duration (within 500ms)
        // 2. Or position equals duration exactly
        // 3. Or video has ended (not playing and near the end)
        final isAtEnd = remaining <= 500 ||
            positionMs >= durationMs ||
            (!_controller!.value.isPlaying &&
                positionMs > 0 &&
                remaining <= 1000);

        if (isAtEnd && !_isVideoCompleted) {
          debugPrint(
              '✅ Video completed! Position: ${positionMs}ms, Duration: ${durationMs}ms');
          setState(() {
            _isVideoCompleted = true;
          });
        }
      }
    }
  }

  /// Video source information - requires cloud URLs from environment variables
  _VideoSource _getVideoSource(String planType) {
    // Get cloud URL from environment variables
    String? cloudUrl;
    String videoName;
    switch (planType) {
      case 'DASH':
        cloudUrl = dotenv.env['DASH_VIDEO_URL'];
        videoName = 'DASH';
        break;
      case 'MyPlate':
        cloudUrl = dotenv.env['MYPLATE_VIDEO_URL'];
        videoName = 'MyPlate';
        break;
      case 'DiabetesPlate':
        cloudUrl = dotenv.env['DIABETES_PLATE_VIDEO_URL'];
        videoName = 'Diabetes Plate';
        break;
      default:
        cloudUrl = dotenv.env['MYPLATE_VIDEO_URL'];
        videoName = 'MyPlate';
    }

    // Cloud URL is required - no local fallback
    if (cloudUrl != null &&
        cloudUrl.isNotEmpty &&
        cloudUrl.startsWith('http')) {
      return _VideoSource(path: cloudUrl, isNetwork: true);
    }

    // If no cloud URL configured, throw an error with helpful message
    String envVarName;
    switch (planType) {
      case 'DASH':
        envVarName = 'DASH_VIDEO_URL';
        break;
      case 'MyPlate':
        envVarName = 'MYPLATE_VIDEO_URL';
        break;
      case 'DiabetesPlate':
        envVarName = 'DIABETES_PLATE_VIDEO_URL';
        break;
      default:
        envVarName = 'MYPLATE_VIDEO_URL';
    }
    throw Exception(
        '$videoName video URL not configured. Please add $envVarName to your .env file with the Firebase Storage URL.');
  }

  void _handleContinue() {
    if (!widget.isTourActive) {
      Navigator.of(context).pop();
      return;
    }

    // If mandatory video watching is enabled, check if video is completed
    if (_isMandatoryVideo && !_isVideoCompleted) {
      // Show a message that user must watch the entire video
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please watch the entire video to continue'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Complete the tour step and navigate back
    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);
    tourProvider.completeCurrentStep();
    Navigator.of(context).pop();

    // Trigger the next showcase step (Add Button) after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ShowcaseView.get().startShowCase([TourKeys.addButtonKey]);
      } catch (e) {
        // Silently handle error
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Video not available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Please add video to assets/nutrition/videos/',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    if (!_isVideoInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
        ),
      );
    }

    return Column(
      children: [
        // Video player
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_controller!),
                  // Play/Pause overlay
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_controller!.value.isPlaying) {
                          _controller!.pause();
                        } else {
                          _controller!.play();
                        }
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: _controller!.value.isPlaying
                          ? const SizedBox.shrink()
                          : const Icon(
                              Icons.play_circle_filled,
                              size: 64,
                              color: Colors.white70,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Video controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),
              const SizedBox(height: 8),
              // Time display and controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatDuration(_controller!.value.position)} / ${_formatDuration(_controller!.value.duration)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _controller!.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                            } else {
                              _controller!.play();
                            }
                          });
                        },
                      ),
                      if (_isMandatoryVideo &&
                          widget.isTourActive &&
                          !_isVideoCompleted)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            'Watch full video to continue',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Continue button
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed:
                _isMandatoryVideo && widget.isTourActive && !_isVideoCompleted
                    ? null
                    : _handleContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              widget.isTourActive ? 'Continue Tour' : 'Done',
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final position = _controller!.value.position;
    final duration = _controller!.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    final canSeek = !_isMandatoryVideo || !widget.isTourActive;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: const Color(0xFFFF6B35),
        inactiveTrackColor: Colors.grey,
        thumbColor: const Color(0xFFFF6B35),
        overlayColor: const Color(0xFFFF6B35).withOpacity(0.2),
        trackHeight: 4.0,
      ),
      child: Slider(
        value: progress.clamp(0.0, 1.0),
        onChanged: canSeek
            ? (value) {
                final newPosition = Duration(
                  milliseconds: (value * duration.inMilliseconds).round(),
                );
                _controller!.seekTo(newPosition);
              }
            : null,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
