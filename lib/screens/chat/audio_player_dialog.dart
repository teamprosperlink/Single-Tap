import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../res/config/app_colors.dart';

class AudioPlayerDialog extends StatefulWidget {
  final String audioUrl;
  final String title;

  const AudioPlayerDialog({
    super.key,
    required this.audioUrl,
    this.title = 'Voice Message',
  });

  static Future<void> show(BuildContext context, String audioUrl, {String? title}) {
    return showDialog(
      context: context,
      builder: (context) => AudioPlayerDialog(
        audioUrl: audioUrl,
        title: title ?? 'Voice Message',
      ),
    );
  }

  @override
  State<AudioPlayerDialog> createState() => _AudioPlayerDialogState();
}

class _AudioPlayerDialogState extends State<AudioPlayerDialog> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      // Set up listeners with mounted checks
      _audioPlayer.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
            _isLoading = false;
          });
        }
      });

      _audioPlayer.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });

      // Load the audio
      await _audioPlayer.setSourceUrl(widget.audioUrl);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDarkMode ? const Color(0xFF1A2B3D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_hasError)
              Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading audio',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              )
            else if (_isLoading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  // Waveform icon (visual representation)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.graphic_eq : Icons.mic,
                      color: Colors.green,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Progress bar
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: Colors.green,
                      inactiveTrackColor: isDarkMode ? Colors.white24 : Colors.black12,
                      thumbColor: Colors.green,
                      overlayColor: Colors.green.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _position.inMilliseconds.toDouble(),
                      min: 0,
                      max: _duration.inMilliseconds.toDouble(),
                      onChanged: (value) async {
                        await _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),

                  // Time display
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Play/Pause button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Rewind 10 seconds
                      IconButton(
                        icon: Icon(
                          Icons.replay_10,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: () async {
                          final newPosition = _position - const Duration(seconds: 10);
                          await _audioPlayer.seek(
                            newPosition.isNegative ? Duration.zero : newPosition,
                          );
                        },
                      ),

                      const SizedBox(width: 16),

                      // Play/Pause
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Forward 10 seconds
                      IconButton(
                        icon: Icon(
                          Icons.forward_10,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: () async {
                          final newPosition = _position + const Duration(seconds: 10);
                          await _audioPlayer.seek(
                            newPosition > _duration ? _duration : newPosition,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
