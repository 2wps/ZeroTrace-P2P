import 'package:flutter/material.dart';

class OutgoingCallDialog extends StatelessWidget {
  final bool isVideo;
  final VoidCallback onCancel;

  const OutgoingCallDialog({
    super.key,
    required this.isVideo,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D131F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF06B6D4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF162032),
                border: Border.all(color: const Color(0xFF06B6D4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withAlpha(100),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isVideo ? Icons.videocam : Icons.phone_forwarded,
                size: 40,
                color: const Color(0xFF06B6D4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'جاري الاتصال والرنين...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'بانتظار رد الطرف الآخر على المكالمة المشفرة',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            // Cancel Call Button
            GestureDetector(
              onTap: onCancel,
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
                  const Text('إلغاء الاتصال', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
