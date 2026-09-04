import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/p2p_session_service.dart';

class MobileCallView extends StatefulWidget {
  final P2PSessionService sessionService;
  final VoidCallback onEndCall;

  const MobileCallView({
    super.key,
    required this.sessionService,
    required this.onEndCall,
  });

  @override
  State<MobileCallView> createState() => _MobileCallViewState();
}

class _MobileCallViewState extends State<MobileCallView> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Remote Video Stream (Fullscreen)
          if (widget.sessionService.remoteRenderer.srcObject != null)
            RTCVideoView(
              widget.sessionService.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: Color(0xFF10B981)),
                  SizedBox(height: 16),
                  Text(
                    'مكالمة مشفرة E2EE (بانتظار فيديو الطرف الآخر)',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

          // Local Video Stream (Picture-in-Picture)
          if (widget.sessionService.localRenderer.srcObject != null && widget.sessionService.isVideoEnabled)
            Positioned(
              top: 40,
              right: 16,
              width: 100,
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF10B981), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RTCVideoView(
                    widget.sessionService.localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // Top Title
          Positioned(
            top: 40,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withAlpha(100)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield, color: Color(0xFF10B981), size: 14),
                  SizedBox(width: 6),
                  Text('مكالمة P2P مباشرة مشفرة', style: TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          ),

          // Bottom Control Actions
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Toggle Mic
                IconButton(
                  icon: Icon(
                    widget.sessionService.isAudioEnabled ? Icons.mic : Icons.mic_off,
                    color: Colors.white,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: widget.sessionService.isAudioEnabled ? const Color(0xFF162032) : Colors.redAccent,
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: () {
                    setState(() {
                      widget.sessionService.toggleMic();
                    });
                  },
                ),

                // End Call Button
                IconButton(
                  icon: const Icon(Icons.call_end, color: Colors.white, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: widget.onEndCall,
                ),

                // Toggle Camera
                IconButton(
                  icon: Icon(
                    widget.sessionService.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: widget.sessionService.isVideoEnabled ? const Color(0xFF162032) : Colors.redAccent,
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: () {
                    setState(() {
                      widget.sessionService.toggleCamera();
                    });
                  },
                ),

                // Switch Camera (Front/Back)
                IconButton(
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 24),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF162032),
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: () => widget.sessionService.switchCamera(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
