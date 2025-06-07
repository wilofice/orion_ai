import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isUserMessage;

  const AudioPlayerWidget({
    Key? key,
    required this.audioUrl,
    this.isUserMessage = false,
  }) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isLoading = true;
  bool _hasError = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // Listen to player state changes
      _audioPlayer.playerStateStream.listen((playerState) {
        if (mounted) {
          setState(() {
            _isLoading = playerState.processingState == ProcessingState.loading ||
                playerState.processingState == ProcessingState.buffering;
          });
        }
      });

      // Listen to duration changes
      _audioPlayer.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _duration = duration;
          });
        }
      });

      // Listen to position changes
      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      // Set the audio source
      await _audioPlayer.setUrl(widget.audioUrl);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      print('Error loading audio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      print('Error toggling playback: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isUserMessage ? Colors.white : Theme.of(context).primaryColor;
    final backgroundColor = widget.isUserMessage ? Theme.of(context).primaryColor : Colors.grey[200];
    
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 20),
            const SizedBox(width: 8),
            Text(
              'Failed to load audio',
              style: TextStyle(
                color: widget.isUserMessage ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          StreamBuilder<PlayerState>(
            stream: _audioPlayer.playerStateStream,
            builder: (context, snapshot) {
              final playerState = snapshot.data;
              final playing = playerState?.playing ?? false;
              final processingState = playerState?.processingState;

              if (_isLoading || processingState == ProcessingState.loading) {
                return Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                );
              }

              return IconButton(
                icon: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  color: primaryColor,
                ),
                onPressed: _togglePlayPause,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Progress indicator and time
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                SizedBox(
                  width: 180,
                  child: StreamBuilder<Duration>(
                    stream: _audioPlayer.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = _duration;
                      
                      return SliderTheme(
                        data: SliderThemeData(
                          thumbColor: primaryColor,
                          activeTrackColor: primaryColor,
                          inactiveTrackColor: primaryColor.withOpacity(0.3),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        ),
                        child: Slider(
                          value: position.inMilliseconds.toDouble(),
                          max: duration.inMilliseconds.toDouble(),
                          onChanged: (value) async {
                            await _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                          },
                        ),
                      );
                    },
                  ),
                ),
                // Time display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: StreamBuilder<Duration>(
                    stream: _audioPlayer.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      return Text(
                        '${_formatDuration(position)} / ${_formatDuration(_duration)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isUserMessage ? Colors.white70 : Colors.black54,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}