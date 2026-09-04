enum MessageType { text, image, file, voice, stego }
enum MessageStatus { sending, sent, delivered, read }

class ChatMessage {
  final String id;
  final String sender; // 'self' or 'peer'
  String text;
  final MessageType type;
  final String? fileMeta;
  final int timestamp;
  MessageStatus status;
  final List<String> reactions;
  bool isBurned;
  bool isEdited;
  final String? quotedText;
  final String? quotedSender;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.type = MessageType.text,
    this.fileMeta,
    required this.timestamp,
    this.status = MessageStatus.sent,
    List<String>? reactions,
    this.isBurned = false,
    this.isEdited = false,
    this.quotedText,
    this.quotedSender,
  }) : reactions = reactions ?? [];

  bool get isSelf => sender == 'self';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'type': type.name,
      'file_meta': fileMeta,
      'timestamp': timestamp,
      'status': status.name,
      'reactions': reactions,
      'is_burned': isBurned,
      'is_edited': isEdited,
      'quoted_text': quotedText,
      'quoted_sender': quotedSender,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    MessageType type = MessageType.text;
    String text = map['text'] ?? '';
    String? qText = map['quoted_text'];
    String? qSender = map['quoted_sender'];

    if (text.startsWith('[QUOTE:') && text.contains(']:')) {
      final endQuoteIdx = text.indexOf(']:');
      final quoteHeader = text.substring(7, endQuoteIdx);
      final quoteParts = quoteHeader.split('|');
      qSender = quoteParts.isNotEmpty ? quoteParts[0] : null;
      qText = quoteParts.length > 1 ? quoteParts.sublist(1).join('|') : null;
      text = text.substring(endQuoteIdx + 2);
    }

    final typeStr = map['type'] as String? ?? 'text';
    if (typeStr == 'image' || text.startsWith('[IMAGE_DATA]:')) {
      type = MessageType.image;
    } else if (typeStr == 'file' || text.startsWith('[FILE_DATA]:')) {
      type = MessageType.file;
    } else if (typeStr == 'voice' || text.startsWith('[VOICE_DATA]:')) {
      type = MessageType.voice;
    } else if (typeStr == 'stego' || text.startsWith('[STEGO_DATA]:')) {
      type = MessageType.stego;
    }

    return ChatMessage(
      id: map['id'] ?? '',
      sender: map['sender'] ?? 'peer',
      text: text,
      type: type,
      fileMeta: map['file_meta'],
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      status: map['status'] == 'read'
          ? MessageStatus.read
          : (map['status'] == 'delivered' ? MessageStatus.delivered : MessageStatus.sent),
      reactions: List<String>.from(map['reactions'] ?? []),
      isBurned: map['is_burned'] == true,
      isEdited: map['is_edited'] == true,
      quotedText: qText,
      quotedSender: qSender,
    );
  }
}
