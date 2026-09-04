import 'dart:async';

class InMemoryChatDb {
  final List<Map<String, dynamic>> _messages = [];
  final _messageStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  bool _isDestroyed = false;

  Stream<List<Map<String, dynamic>>> get messageStream => _messageStreamController.stream;

  void initialize() {
    _messages.clear();
    _isDestroyed = false;
    _notify();
  }

  void insertMessage({
    required String id,
    required String sender,
    String? text,
    String? fileMeta,
    required String status,
    String type = 'text',
    int? timestamp,
  }) {
    if (_isDestroyed) return;

    final existingIndex = _messages.indexWhere((m) => m['id'] == id);
    if (existingIndex >= 0) return;

    _messages.add({
      'id': id,
      'sender': sender,
      'text': text,
      'file_meta': fileMeta,
      'status': status,
      'type': type,
      'reactions': <String>[],
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      'is_edited': false,
      'is_burned': false,
    });

    _notify();
  }

  void updateMessageStatus(String messageId, String status) {
    if (_isDestroyed) return;
    final index = _messages.indexWhere((m) => m['id'] == messageId);
    if (index >= 0) {
      _messages[index]['status'] = status;
      _notify();
    }
  }

  void markAllPeerMessagesAsRead() {
    if (_isDestroyed) return;
    bool hasChanged = false;
    for (var msg in _messages) {
      if (msg['sender'] == 'peer' && msg['status'] != 'read') {
        msg['status'] = 'read';
        hasChanged = true;
      }
    }
    if (hasChanged) {
      _notify();
    }
  }

  void editMessage(String messageId, String newText) {
    if (_isDestroyed) return;
    final index = _messages.indexWhere((m) => m['id'] == messageId);
    if (index >= 0) {
      _messages[index]['text'] = newText;
      _messages[index]['is_edited'] = true;
      _notify();
    }
  }

  void addReaction(String messageId, String emoji) {
    if (_isDestroyed) return;
    final index = _messages.indexWhere((m) => m['id'] == messageId);
    if (index >= 0) {
      final List<String> reactions = List<String>.from(_messages[index]['reactions'] ?? []);
      if (!reactions.contains(emoji)) {
        reactions.add(emoji);
        _messages[index]['reactions'] = reactions;
        _notify();
      }
    }
  }

  void deleteMessage(String messageId) {
    if (_isDestroyed) return;
    final index = _messages.indexWhere((m) => m['id'] == messageId);
    if (index >= 0) {
      _messages[index]['text'] = '🔥 تم حرق ومسح هذه الرسالة';
      _messages[index]['file_meta'] = null;
      _messages[index]['is_burned'] = true;
      _notify();
    }
  }

  List<Map<String, dynamic>> getAllMessages() {
    if (_isDestroyed) return [];
    return List.unmodifiable(_messages);
  }

  void _notify() {
    if (!_isDestroyed && !_messageStreamController.isClosed) {
      _messageStreamController.add(List.from(_messages));
    }
  }

  void wipeAndDestroy() {
    _isDestroyed = true;
    for (var msg in _messages) {
      msg['text'] = '';
      msg['file_meta'] = '';
      msg['reactions'] = [];
    }
    _messages.clear();

    if (!_messageStreamController.isClosed) {
      _messageStreamController.add([]);
    }
  }
}
