import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class PinnedMessageHeader extends StatelessWidget {
  final ChatMessage pinnedMessage;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  const PinnedMessageHeader({
    super.key,
    required this.pinnedMessage,
    required this.onTap,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF162032),
          border: const Border(
            bottom: BorderSide(color: Color(0xFF10B981), width: 1.5),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.push_pin, color: Color(0xFF10B981), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'رسالة مثبتة',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                  Text(
                    pinnedMessage.text,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.white54),
              onPressed: onUnpin,
              tooltip: 'إلغاء التثبيت',
            ),
          ],
        ),
      ),
    );
  }
}
