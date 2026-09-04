import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioBubblePlayer extends StatefulWidget {
  final String base64Audio;
  final bool isSelf;

  const AudioBubblePlayer({
    super.key,
    required this.base64Audio,
    required this.isSelf,
  });

  @override
  State<AudioBubblePlayer> createState() => _AudioBubblePlayerState();
}

class _AudioBubblePlayerState extends State<AudioBubblePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;
  late final List<double> _waveformHeights;

  @override
  void initState() {
    super.initState();
    // Generate deterministic waveform amplitudes for dynamic visualizer
    final rand = Random(widget.base64Audio.hashCode);
    _waveformHeights = List.generate(24, (i) => 6.0 + rand.nextDouble() * 18.0);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    HapticFeedback.lightImpact();
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      try {
        final bytes = base64Decode(widget.base64Audio);
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
        await _audioPlayer.play(BytesSource(bytes));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تشغيل مقطع الصوت المشفر في الـ RAM')),
          );
        }
      }
    }
  }

  void _toggleSpeed() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 1.0;
      }
    });
    _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    final playedBarsCount = (_waveformHeights.length * progress).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Play / Pause Button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isSelf ? Colors.white.withAlpha(50) : const Color(0xFF10B981).withAlpha(40),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Waveform Visualizer & Timer
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 24 Dynamic Waveform Bars
              GestureDetector(
                onHorizontalDragUpdate: (details) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox != null && _duration.inMilliseconds > 0) {
                    final newProgress = (details.localPosition.dx / 130).clamp(0.0, 1.0);
                    final newPos = Duration(milliseconds: (_duration.inMilliseconds * newProgress).toInt());
                    _audioPlayer.seek(newPos);
                  }
                },
                child: SizedBox(
                  height: 24,
                  width: 130,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(_waveformHeights.length, (index) {
                      final isPlayed = index < playedBarsCount;
                      return Container(
                        width: 3.0,
                        height: _waveformHeights[index],
                        decoration: BoxDecoration(
                          color: isPlayed
                              ? Colors.white
                              : (widget.isSelf ? Colors.white.withAlpha(90) : Colors.white38),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Time & Speed Badges
              Row(
                children: [
                  Text(
                    _isPlaying
                        ? _formatDuration(_position)
                        : (_duration > Duration.zero ? _formatDuration(_duration) : '0:05'),
                    style: TextStyle(
                      fontSize: 10,
                      color: widget.isSelf ? Colors.white.withAlpha(220) : Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _toggleSpeed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '${_playbackSpeed}x',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
