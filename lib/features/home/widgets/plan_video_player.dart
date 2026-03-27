import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
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

class PlanVideoPreloader {
  static final Map<String, VideoPlayerController> _cache = {};
  static final Map<String, Future<void>> _inFlight = {};

  static String _key(String planType, bool useFullVideo) =>
      '$planType|${useFullVideo ? 'full' : 'short'}';

  static Future<void> preload(String planType,
      {bool useFullVideo = false}) async {
    final key = _key(planType, useFullVideo);
    final existing = _cache[key];
    if (existing != null && existing.value.isInitialized) {
      return;
    }
    final loading = _inFlight[key];
    if (loading != null) {
      await loading;
      return;
    }

    _inFlight[key] = () async {
      try {
        final source =
            _PlanVideoPlayerState.getVideoSourceStatic(planType, useFullVideo);
        VideoPlayerController controller;
        if (source.isNetwork) {
          controller = VideoPlayerController.networkUrl(Uri.parse(source.path));
        } else {
          controller = VideoPlayerController.asset(source.path);
        }
        await controller.initialize();
        await controller.setVolume(0);
        await controller.pause();
        _cache[key] = controller;
      } catch (e) {
        debugPrint('PlanVideoPreloader preload error: $e');
      } finally {
        _inFlight.remove(key);
      }
    }();
    await _inFlight[key];
  }

  static VideoPlayerController? takeController(
      String planType, bool useFullVideo) {
    final key = _key(planType, useFullVideo);
    final controller = _cache.remove(key);
    return controller;
  }

  static void storeController(
      String planType, bool useFullVideo, VideoPlayerController controller) {
    final key = _key(planType, useFullVideo);
    final existing = _cache[key];
    if (existing == controller) return;
    if (existing != null) {
      existing.dispose();
    }
    _cache[key] = controller;
  }
}

class PlanVideoPlayer extends StatefulWidget {
  final String planType;
  final String title;
  final bool isTourActive;
  final VoidCallback? onFinish; // For signup flow
  final bool isSignupMode; // For signup flow
  final bool
      useFullVideo; // Use full video URLs (for tour) instead of short videos (for signup)

  const PlanVideoPlayer({
    Key? key,
    required this.planType,
    required this.title,
    required this.isTourActive,
    this.onFinish,
    this.isSignupMode = false,
    this.useFullVideo = false,
  }) : super(key: key);

  @override
  State<PlanVideoPlayer> createState() => _PlanVideoPlayerState();
}

class _PlanVideoPlayerState extends State<PlanVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  static const double _playbackVolume = 1.0;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isVideoCompleted = false;
  bool _isVideoInitialized = false;
  bool _isSubmitting = false; // For signup mode registration
  String? _errorMessage;
  VoidCallback? _videoListener;

  // Check if video watching is mandatory from env var
  bool get _isMandatoryVideo =>
      widget.isSignupMode ||
      (dotenv.env['MANDATORY_PLAN_VIDEO']?.toLowerCase() == 'true');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Try to reuse preloaded controller if available
      final preloaded = PlanVideoPreloader.takeController(
          widget.planType, widget.useFullVideo);
      if (preloaded != null) {
        _controller = preloaded;
        _attachControllerListener();
        setState(() {
          _isLoading = false;
          _isVideoInitialized = true;
        });
        // Controller is preloaded muted; restore volume for playback.
        _controller!.setVolume(_playbackVolume);
        _controller!.play();
        return;
      }

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
      await _controller!.setVolume(_playbackVolume);

      // Listen for video completion and position updates
      _attachControllerListener();

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

  void _attachControllerListener() {
    final c = _controller;
    if (c == null) return;
    _videoListener ??= () {
      if (!mounted) return;
      _checkVideoCompletion();
      // Pausing/backgrounding can trigger controller notifications during build.
      // Schedule UI refresh safely after the current frame.
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {}); // Update UI for progress bar
        });
      } else {
        setState(() {}); // Update UI for progress bar
      }
    };
    c.addListener(_videoListener!);
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
    return _PlanVideoPlayerState.getVideoSourceStatic(
        planType, widget.useFullVideo);
  }

  /// Static helper so preloader can compute video source without a widget.
  static _VideoSource getVideoSourceStatic(String planType, bool useFullVideo) {
    // Get cloud URL from environment variables
    // If useFullVideo is true, try full video URLs first, then fall back to regular URLs
    String? cloudUrl;
    String videoName;
    String? envVarName;

    switch (planType) {
      case 'DASH':
        if (useFullVideo) {
          cloudUrl = dotenv.env['DASH_VIDEO_URL_FULL'];
          envVarName = 'DASH_VIDEO_URL_FULL';
        }
        // Fall back to regular URL if full video not found
        cloudUrl ??= dotenv.env['DASH_VIDEO_URL'];
        envVarName ??= 'DASH_VIDEO_URL';
        videoName = 'DASH';
        break;
      case 'MyPlate':
        if (useFullVideo) {
          cloudUrl = dotenv.env['MYPLATE_VIDEO_URL_FULL'];
          envVarName = 'MYPLATE_VIDEO_URL_FULL';
        }
        // Fall back to regular URL if full video not found
        cloudUrl ??= dotenv.env['MYPLATE_VIDEO_URL'];
        envVarName ??= 'MYPLATE_VIDEO_URL';
        videoName = 'MyPlate';
        break;
      case 'DiabetesPlate':
        if (useFullVideo) {
          cloudUrl = dotenv.env['DIABETES_PLATE_VIDEO_URL_FULL'];
          envVarName = 'DIABETES_PLATE_VIDEO_URL_FULL';
        }
        // Fall back to regular URL if full video not found
        cloudUrl ??= dotenv.env['DIABETES_PLATE_VIDEO_URL'];
        envVarName ??= 'DIABETES_PLATE_VIDEO_URL';
        videoName = 'Diabetes Plate';
        break;
      default:
        if (useFullVideo) {
          cloudUrl = dotenv.env['MYPLATE_VIDEO_URL_FULL'];
          envVarName = 'MYPLATE_VIDEO_URL_FULL';
        }
        // Fall back to regular URL if full video not found
        cloudUrl ??= dotenv.env['MYPLATE_VIDEO_URL'];
        envVarName ??= 'MYPLATE_VIDEO_URL';
        videoName = 'MyPlate';
    }

    // Cloud URL is required - no local fallback
    if (cloudUrl != null &&
        cloudUrl.isNotEmpty &&
        cloudUrl.startsWith('http')) {
      return _VideoSource(path: cloudUrl, isNetwork: true);
    }

    // If no cloud URL configured, throw an error with helpful message
    throw Exception(
        '$videoName video URL not configured. Please add $envVarName to your .env file with the Firebase Storage URL.');
  }

  void _handleContinue() async {
    // Handle signup flow
    if (widget.isSignupMode && widget.onFinish != null) {
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

      // Show loading state in button
      setState(() {
        _isSubmitting = true;
      });

      // Wait for UI to update with loading state, then call onFinish
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Call onFinish which will trigger registration
        widget.onFinish!();
      });
      return;
    }

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

  void _pauseAndMuteIfPlaying() {
    final c = _controller;
    if (c == null) return;
    try {
      if (c.value.isPlaying) {
        // Don't await here: pausing may be triggered during route/tab transitions.
        c.pause();
      }
      // Defensive: ensure no audio leaks while cached / backgrounded.
      c.setVolume(0);
    } catch (_) {
      // Best-effort only.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ensure no audio continues when app is backgrounded/locked.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pauseAndMuteIfPlaying();
    }
  }

  @override
  void deactivate() {
    // When leaving the page (e.g., switching tabs or popping route),
    // stop playback immediately to avoid background audio.
    _pauseAndMuteIfPlaying();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _controller;
    if (c != null && _videoListener != null) {
      c.removeListener(_videoListener!);
    }
    if (c != null && c.value.isInitialized) {
      _pauseAndMuteIfPlaying();
      PlanVideoPreloader.storeController(
          widget.planType, widget.useFullVideo, c);
    } else {
      c?.dispose();
    }
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
                  // Tap anywhere on video to play/pause.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final c = _controller;
                        if (c == null) return;

                        // If at end, restart from beginning.
                        final duration = c.value.duration;
                        final position = c.value.position;
                        final isAtEnd = duration != Duration.zero &&
                            (duration - position) <=
                                const Duration(milliseconds: 300);
                        if (isAtEnd) {
                          await c.seekTo(Duration.zero);
                        }

                        if (c.value.isPlaying) {
                          c.pause();
                          setState(() {});
                        } else {
                          await c.setVolume(_playbackVolume);
                          c.play();
                          setState(() {});
                        }
                      },
                      child: Center(
                        child: _controller!.value.isPlaying
                            ? const SizedBox.shrink()
                            : const Icon(
                                Icons.play_circle_filled,
                                size: 64,
                                color: Colors.white70,
                              ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),
              // Time display
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      '${_formatDuration(_controller!.value.position)} / ${_formatDuration(_controller!.value.duration)}',
                      style: TextStyle(
                        fontSize: 12 *
                            MediaQuery.textScaleFactorOf(context)
                                .clamp(0.8, 1.0),
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Continue button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: (_isSubmitting ||
                    (_isMandatoryVideo &&
                        !_isVideoCompleted &&
                        (widget.isSignupMode || widget.isTourActive)))
                ? null
                : _handleContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.isSignupMode
                        ? "Let's Get Started!"
                        : widget.isTourActive
                            ? 'Continue Tour'
                            : 'Done',
                  ),
          ),
        ),
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

    bool canSeek;
    if (_isMandatoryVideo && (widget.isTourActive || widget.isSignupMode)) {
      // For mandatory videos in signup/tour flows, disallow scrubbing until
      // the user has watched the full video once.
      canSeek = _isVideoCompleted;
    } else {
      canSeek = true;
    }

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: const Color(0xFFFF6B35),
        inactiveTrackColor: const Color(0xFFFFC4A3),
        thumbColor: const Color(0xFFFF6B35),
        overlayColor: const Color(0xFFFF6B35).withOpacity(0.2),
        disabledActiveTrackColor: const Color(0xFFFF6B35),
        disabledInactiveTrackColor: const Color(0xFFFFC4A3),
        disabledThumbColor: const Color(0xFFFF6B35),
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
