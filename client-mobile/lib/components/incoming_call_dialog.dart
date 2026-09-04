import 'package:flutter/material.dart';

class IncomingCallDialog extends StatelessWidget {
  final bool isVideo;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallDialog({
    super.key,
    required this.isVideo,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D131F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF162032),
                border: Border.all(color: const Color(0xFF10B981), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withAlpha(100),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isVideo ? Icons.videocam : Icons.phone_in_talk,
                size: 40,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'مكالمة مشفرة واردة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              isVideo ? '📹 مكالمة فيديو HD مشفرة E2EE' : '📞 مكالمة صوتية مشفرة P2P',
              style: const TextStyle(fontSize: 12, color: Color(0xFF06B6D4)),
            ),
            const SizedBox(height: 24),
            // Accept & Decline Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline (Red)
                GestureDetector(
                  onTap: onDecline,
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 6),
                      const Text('رفض', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                // Accept (Green)
                GestureDetector(
                  onTap: onAccept,
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0xFF10B981), blurRadius: 10, spreadRadius: 1),
                          ],
                        ),
                        child: Icon(
                          isVideo ? Icons.videocam : Icons.phone,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('قبول', style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
