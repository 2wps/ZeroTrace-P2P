import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import 'interactive_image_viewer.dart';
import 'audio_bubble_player.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;
  final Function(String emoji)? onQuickReact;

  const ChatBubble({
    super.key,
    required this.message,
    required this.onLongPress,
    required this.onSwipeReply,
    this.onQuickReact,
  });

  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = message.isSelf;

    return Dismissible(
      key: Key('msg-${message.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        onSwipeReply();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.reply, color: Color(0xFF10B981), size: 24),
      ),
      child: Align(
        alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          onDoubleTap: () {
            if (onQuickReact != null) {
              onQuickReact!('❤️');
              HapticFeedback.mediumImpact();
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              gradient: isSelf
                  ? const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelf ? null : const Color(0xFF162032),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isSelf ? const Radius.circular(16) : const Radius.circular(4),
                bottomRight: isSelf ? const Radius.circular(4) : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isSelf ? 30 : 50),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Quoted Reply Card
                  if (message.quotedText != null && message.quotedText!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(
                          right: BorderSide(color: Color(0xFF06B6D4), width: 3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.quotedSender == 'self' ? 'أنت' : 'الطرف الآخر',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message.quotedText!,
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  _buildContent(context),
                  const SizedBox(height: 3),
                  // Timestamp, Edited Tag, & Checkmarks
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isEdited) ...[
                        Text(
                          'معدلة ',
                          style: TextStyle(
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                            color: isSelf ? Colors.white.withAlpha(160) : Colors.grey,
                          ),
                        ),
                      ],
                      Text(
                        _formatTimestamp(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelf ? Colors.white.withAlpha(180) : Colors.grey,
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.status == MessageStatus.read ? Icons.done_all : Icons.done,
                          size: 13,
                          color: message.status == MessageStatus.read
                              ? const Color(0xFF06B6D4)
                              : Colors.white.withAlpha(200),
                        ),
                      ],
                    ],
                  ),
                  // Emoji Reactions
                  if (message.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Wrap(
                        spacing: 4,
                        children: message.reactions.map((r) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(r, style: const TextStyle(fontSize: 12)),
                        )).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.isBurned) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, color: Colors.amberAccent, size: 16),
          SizedBox(width: 6),
          Text(
            'تم حرق الرسالة ومسحها من الذاكرة',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70),
          ),
        ],
      );
    }

    switch (message.type) {
      case MessageType.image:
        final base64Img = message.text.replaceFirst('[IMAGE_DATA]:', '');
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => InteractiveImageViewer(base64Image: base64Img)),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Image.memory(
                  base64Decode(base64Img),
                  width: 220,
                  fit: BoxFit.cover,
                ),
                Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
        );

      case MessageType.file:
        final parts = message.text.replaceFirst('[FILE_DATA]:', '').split('|');
        final fileName = parts.isNotEmpty ? parts[0] : 'ملف';
        final fileSize = parts.length > 1 ? '${(int.tryParse(parts[1]) ?? 0) ~/ 1024} KB' : '';

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_drive_file, color: Color(0xFFF59E0B), size: 24),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(fileSize, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        );

      case MessageType.voice:
        final base64Audio = message.text.replaceFirst('[VOICE_DATA]:', '');
        return AudioBubblePlayer(
          base64Audio: base64Audio,
          isSelf: message.isSelf,
        );

      case MessageType.stego:
        final parts = message.text.replaceFirst('[STEGO_DATA]:', '').split('|HEADER|');
        final secretText = parts.isNotEmpty ? parts[0] : '';
        final base64Img = parts.length > 1 ? parts[1] : '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (base64Img.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(base64Img),
                  width: 220,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withAlpha(40),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF06B6D4).withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_open, size: 12, color: Color(0xFF06B6D4)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'نص إخفائي: $secretText',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case MessageType.text:
        return Text(
          message.text,
          style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.35),
        );
    }
  }
}
