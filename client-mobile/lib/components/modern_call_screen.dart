import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/p2p_session_service.dart';

class ModernCallScreen extends StatefulWidget {
  final P2PSessionService sessionService;
  final VoidCallback onEndCall;

  const ModernCallScreen({
    super.key,
    required this.sessionService,
    required this.onEndCall,
  });

  @override
  State<ModernCallScreen> createState() => _ModernCallScreenState();
}

class _ModernCallScreenState extends State<ModernCallScreen> {
  int _callDurationSeconds = 0;
  Timer? _timer;
  bool _isSpeakerOn = true;
  StreamSubscription? _callSub;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDurationSeconds++);
      }
    });

    _callSub = widget.sessionService.callStateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _callSub?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final hasRemoteVideo = widget.sessionService.remoteRenderer.srcObject != null &&
        widget.sessionService.isVideoEnabled;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          widget.onEndCall();
        }
      },
      child: Container(
        color: const Color(0xFF07090E),
        child: Stack(
        children: [
          // 1. Remote Video Stream or Futuristic Audio Calling Avatar
          if (hasRemoteVideo)
            SizedBox.expand(
              child: RTCVideoView(
                widget.sessionService.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF162032),
                      border: Border.all(color: const Color(0xFF10B981), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withAlpha(80),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person, size: 64, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'مكالمة P2P مشفرة E2EE',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_callDurationSeconds),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Animated Audio Wave Spectrum
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [8, 18, 28, 14, 36, 22, 30, 12, 24, 16, 26]
                        .map((h) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              width: 3.5,
                              height: h.toDouble(),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

          // 2. Picture-in-Picture Local Video
          if (widget.sessionService.localRenderer.srcObject != null && widget.sessionService.isVideoEnabled)
            Positioned(
              top: 45,
              right: 16,
              width: 110,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: const Color(0xFF10B981), width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: RTCVideoView(
                    widget.sessionService.localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // 3. Top Call Info Header
          Positioned(
            top: 45,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Color(0xFF10B981), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(_callDurationSeconds),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  if (widget.sessionService.isScreenSharing) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF06B6D4), borderRadius: BorderRadius.circular(6)),
                      child: const Text('مشاركة الشاشة', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 4. Floating Modern Bottom Call Action Bar
          Positioned(
            bottom: 35,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D131F).withAlpha(230),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Mic
                  _buildCallBtn(
                    icon: widget.sessionService.isAudioEnabled ? Icons.mic : Icons.mic_off,
                    bgColor: widget.sessionService.isAudioEnabled ? const Color(0xFF1E293B) : Colors.redAccent,
                    onTap: () {
                      setState(() => widget.sessionService.toggleMic());
                    },
                  ),
                  // Screen Share
                  _buildCallBtn(
                    icon: widget.sessionService.isScreenSharing ? Icons.screen_share : Icons.stop_screen_share,
                    bgColor: widget.sessionService.isScreenSharing ? const Color(0xFF06B6D4) : const Color(0xFF1E293B),
                    onTap: () {
                      widget.sessionService.toggleScreenShare();
                    },
                  ),
                  // Speakerphone
                  _buildCallBtn(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                    bgColor: const Color(0xFF1E293B),
                    onTap: () {
                      setState(() => _isSpeakerOn = !_isSpeakerOn);
                    },
                  ),
                  // End Call (Red)
                  GestureDetector(
                    onTap: widget.onEndCall,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.redAccent, blurRadius: 15, spreadRadius: 1),
                        ],
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                    ),
                  ),
                  // Video Toggle
                  _buildCallBtn(
                    icon: widget.sessionService.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                    bgColor: widget.sessionService.isVideoEnabled ? const Color(0xFF1E293B) : Colors.redAccent,
                    onTap: () {
                      setState(() => widget.sessionService.toggleCamera());
                    },
                  ),
                  // Flip Camera
                  _buildCallBtn(
                    icon: Icons.flip_camera_ios,
                    bgColor: const Color(0xFF1E293B),
                    onTap: () => widget.sessionService.switchCamera(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildCallBtn({required IconData icon, required Color bgColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}
