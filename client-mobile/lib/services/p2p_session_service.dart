import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/crypto/crypto_engine.dart';
import '../core/storage/in_memory_db.dart';
import 'foreground_service_handler.dart';
import 'in_app_host_server.dart';

enum P2PRole { host, guest }
enum P2PState { idle, signaling, connecting, connected, disconnected, error }
enum NetworkMode { globalInternet, localWifi, customRelay }

class P2PSessionService {
  final InMemoryChatDb db = InMemoryChatDb();
  final InAppHostServer inAppServer = InAppHostServer();

  P2PState state = P2PState.idle;
  String? errorMessage;
  String statusMessage = 'خامل';

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  WebSocketChannel? _signalingChannel;
  StreamSubscription? _signalingSubscription;
  StreamSubscription? _inAppServerSubscription;

  // Media Call State
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  MediaStream? localStream;
  MediaStream? remoteStream;
  bool isCalling = false;
  bool isVideoEnabled = true;
  bool isAudioEnabled = true;
  bool isScreenSharing = false;

  // Whiteboard Stream
  final StreamController<Map<String, dynamic>> _drawEventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get drawEventStream => _drawEventController.stream;

  // Call Signaling Events Stream
  final StreamController<Map<String, dynamic>> _callEventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callEventStream => _callEventController.stream;

  // Typing & Latency Streams
  final StreamController<bool> _typingController = StreamController<bool>.broadcast();
  Stream<bool> get typingStream => _typingController.stream;
  
  final StreamController<int> _latencyController = StreamController<int>.broadcast();
  Stream<int> get latencyStream => _latencyController.stream;
  Timer? _pingTimer;

  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _hasRemoteDescription = false;
  String? sessionId;
  String? preSharedKey;
  P2PRole? role;
  bool isUsingInAppServer = false;
  String? activeHostUrl;
  NetworkMode currentNetworkMode = NetworkMode.globalInternet;

  static const List<String> globalRelayServers = [
    'wss://free.v2.sig.ephemeral.relay/ws',
    'wss://socketsbay.com/wss/v2/1/demo/',
    'wss://echo.websocket.events',
  ];

  final _stateStreamController = StreamController<P2PState>.broadcast();
  Stream<P2PState> get stateStream => _stateStreamController.stream;

  final _callStateController = StreamController<bool>.broadcast();
  Stream<bool> get callStateStream => _callStateController.stream;

  Future<void> initialize() async {
    db.initialize();
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
    } catch (_) {}
  }

  /// Start Host Session directly on the phone or via Global Internet Relay
  Future<String> startHostSession({
    required NetworkMode mode,
    String? customUrl,
    String? appBaseUrl = 'https://secure.p2p.app/join',
    String? preferredIp,
  }) async {
    role = P2PRole.host;
    currentNetworkMode = mode;
    sessionId = FlutterCryptoEngine.generateSessionId();
    preSharedKey = FlutterCryptoEngine.generateSessionSecret();

    String targetSignalingUrl = '';

    if (mode == NetworkMode.localWifi) {
      isUsingInAppServer = true;
      targetSignalingUrl = await inAppServer.start();
      if (preferredIp != null && preferredIp.isNotEmpty) {
        targetSignalingUrl = 'ws://$preferredIp:${inAppServer.port ?? 8080}';
      }
      activeHostUrl = targetSignalingUrl;
      statusMessage = 'السيرفر المحلي يعمل في الـ RAM.. بانتظار مسح الـ QR';

      _inAppServerSubscription?.cancel();
      _inAppServerSubscription = inAppServer.signalStream.listen((msg) async {
        final action = msg['action'];
        if (action == 'peer-connected' || action == 'join') {
          statusMessage = 'تم اتصال الهاتف الآخر بنجاح 🟢';
          _updateState(P2PState.connected);
          _startPingMeasurement();
          await _createOffer();
        } else {
          await _handleUniversalSignal(msg);
        }
      });
    } else if (mode == NetworkMode.globalInternet) {
      isUsingInAppServer = false;
      // Default to high-availability global public relay
      targetSignalingUrl = (customUrl != null && customUrl.isNotEmpty) ? customUrl : globalRelayServers[0];
      activeHostUrl = targetSignalingUrl;
      statusMessage = 'جاري تهيئة قناة الاتصال عبر الإنترنت والشبكات المختلفة...';
    } else {
      isUsingInAppServer = false;
      targetSignalingUrl = (customUrl != null && customUrl.isNotEmpty) ? customUrl : 'ws://127.0.0.1:8080';
      activeHostUrl = targetSignalingUrl;
      statusMessage = 'جاري الاتصال بالسيرفر الوسيط المخصص...';
    }

    final uri = Uri.parse(appBaseUrl ?? 'https://secure.p2p.app/join');
    final encodedHost = Uri.encodeComponent(targetSignalingUrl);
    final fragment = 'sid=$sessionId&key=$preSharedKey&host=$encodedHost&mode=${mode.name}';
    final inviteUrl = uri.replace(fragment: fragment).toString();

    MobileBackgroundHandler.startForegroundService(
      title: 'Zero-Trace P2P نشط',
      text: mode == NetworkMode.globalInternet ? 'اتصال عابر للشبكات (4G/5G/Wi-Fi)' : 'سيرفر مؤقت في الـ RAM',
    ).catchError((_) {});

    try {
      await _initWebRTC();
      final dcInit = RTCDataChannelInit()..ordered = true;
      _dataChannel = await _peerConnection!.createDataChannel('p2p-data', dcInit);
      _setupDataChannel(_dataChannel!);
    } catch (e) {
      errorMessage = 'WebRTC Error: $e';
    }

    if (!isUsingInAppServer && targetSignalingUrl.isNotEmpty) {
      _connectSignaling(targetSignalingUrl).catchError((err) {
        errorMessage = 'خطأ الاتصال: $err';
        _updateState(P2PState.error);
      });
    } else {
      _updateState(P2PState.signaling);
    }

    return inviteUrl;
  }

  /// Join Guest Session from QR code or invite link
  Future<void> joinGuestSession({
    required String signalingUrl,
    required String targetSessionId,
    required String targetKey,
    NetworkMode mode = NetworkMode.globalInternet,
  }) async {
    role = P2PRole.guest;
    sessionId = targetSessionId;
    preSharedKey = targetKey;
    isUsingInAppServer = false;
    currentNetworkMode = mode;
    activeHostUrl = signalingUrl;

    statusMessage = 'جاري الاتصال بالطرف الآخر عبر نفق P2P E2EE...';
    _updateState(P2PState.connecting);

    try {
      await _initWebRTC();
      if (signalingUrl.trim().isNotEmpty) {
        await _connectSignaling(signalingUrl.trim());
      }
    } catch (e) {
      errorMessage = e.toString();
      statusMessage = 'فشل الاتصال: $e';
      _updateState(P2PState.error);
      rethrow;
    }
  }

  Future<void> _connectSignaling(String url) async {
    try {
      await _signalingSubscription?.cancel();
      _signalingSubscription = null;
      _signalingChannel?.sink.close();

      final uri = Uri.parse(url);
      _signalingChannel = WebSocketChannel.connect(uri);

      _sendSignalEnvelope({
        'action': 'join',
        'sessionId': sessionId,
        'role': role == P2PRole.host ? 'host' : 'guest',
      });

      _updateState(P2PState.connected);
      _startPingMeasurement();

      _signalingSubscription = _signalingChannel!.stream.listen(
        (message) async {
          try {
            final raw = jsonDecode(message.toString());
            await _handleUniversalSignal(raw['payload'] ?? raw);
          } catch (_) {}
        },
        onError: (err) {
          errorMessage = 'تعذر الاتصال بعنوان السيرفر: $err';
          statusMessage = 'خطأ في الاتصال';
          _updateState(P2PState.error);
        },
        onDone: () {
          if (state != P2PState.connected) {
            _updateState(P2PState.disconnected);
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      errorMessage = 'تعذر الاتصال بالشبكة: $e';
      _updateState(P2PState.error);
      rethrow;
    }
  }

  void _sendSignalEnvelope(Map<String, dynamic> payload) {
    if (isUsingInAppServer) {
      inAppServer.broadcast(payload);
    } else if (_signalingChannel != null) {
      try {
        _signalingChannel!.sink.add(jsonEncode(payload));
      } catch (_) {}
    }
  }

  Future<void> _handleUniversalSignal(Map<String, dynamic> signal) async {
    final action = signal['action'];

    if (action == 'offer') {
      final data = signal['payload'] ?? signal['data'] ?? signal;
      if (_peerConnection != null) {
        try {
          await _peerConnection!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
          _hasRemoteDescription = true;
          _flushPendingCandidates();
          final answer = await _peerConnection!.createAnswer({
            'offerToReceiveAudio': 1,
            'offerToReceiveVideo': 1,
          });
          await _peerConnection!.setLocalDescription(answer);

          _sendSignalEnvelope({
            'action': 'answer',
            'sessionId': sessionId,
            'role': role == P2PRole.host ? 'host' : 'guest',
            'payload': {
              'sdp': answer.sdp,
              'type': answer.type,
            },
          });
        } catch (_) {}
      }
      _updateState(P2PState.connected);
    } else if (action == 'answer') {
      final data = signal['payload'] ?? signal['data'] ?? signal;
      if (_peerConnection != null) {
        try {
          await _peerConnection!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
          _hasRemoteDescription = true;
          _flushPendingCandidates();
        } catch (_) {}
      }
      _updateState(P2PState.connected);
    } else if (action == 'candidate') {
      final data = signal['payload'] ?? signal['data'] ?? signal;
      if (data['candidate'] != null && _peerConnection != null) {
        final cand = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        if (_hasRemoteDescription) {
          try {
            await _peerConnection!.addCandidate(cand);
          } catch (_) {}
        } else {
          _pendingIceCandidates.add(cand);
        }
      }
    } else if (action == 'direct-chat') {
      final msgId = signal['id'] ?? FlutterCryptoEngine.generateSessionId();
      _receiveIncomingChatMessage(msgId, signal['text']);
      _sendSignalEnvelope({'action': 'msg-delivered', 'id': msgId});
      _updateState(P2PState.connected);
    } else if (action == 'msg-delivered') {
      db.updateMessageStatus(signal['id'], 'delivered');
    } else if (action == 'msg-read') {
      db.updateMessageStatus(signal['id'], 'read');
    } else if (action == 'draw') {
      _drawEventController.add(signal['event']);
    } else if (action == 'typing') {
      _typingController.add(signal['isTyping'] == true);
    } else if (action == 'reaction') {
      db.addReaction(signal['messageId'], signal['emoji']);
    } else if (action == 'edit-msg') {
      db.editMessage(signal['messageId'], signal['newText']);
    } else if (action == 'delete-msg') {
      db.deleteMessage(signal['messageId']);
    } else if (action == 'call-request') {
      _callEventController.add({
        'type': 'incoming',
        'isVideo': signal['isVideo'] == true,
      });
    } else if (action == 'call-accept') {
      _callEventController.add({
        'type': 'accepted',
        'isVideo': signal['isVideo'] == true,
      });
      await _createOffer();
    } else if (action == 'call-decline') {
      _callEventController.add({'type': 'declined'});
      endCall();
    } else if (action == 'call-cancel') {
      _callEventController.add({'type': 'cancelled'});
      endCall();
    } else if (action == 'call-end') {
      _callEventController.add({'type': 'ended'});
      endCall();
    } else if (action == 'ping') {
      _sendSignalEnvelope({'action': 'pong', 't': signal['t']});
    } else if (action == 'pong') {
      final sentTime = signal['t'] as int?;
      if (sentTime != null) {
        final rtt = DateTime.now().millisecondsSinceEpoch - sentTime;
        _latencyController.add(rtt);
      }
    }
  }

  void _flushPendingCandidates() async {
    if (_peerConnection == null) return;
    for (final cand in List.from(_pendingIceCandidates)) {
      try {
        await _peerConnection!.addCandidate(cand);
      } catch (_) {}
    }
    _pendingIceCandidates.clear();
  }

  void _receiveIncomingChatMessage(String id, String text) {
    db.insertMessage(
      id: id,
      sender: 'peer',
      text: text,
      status: 'received',
    );
  }

  void _startPingMeasurement() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (state == P2PState.connected) {
        _sendSignalEnvelope({
          'action': 'ping',
          't': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  void sendReadReceipt(String messageId) {
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
          'type': 'msg-read',
          'id': messageId,
        })));
      } catch (_) {}
    }
    _sendSignalEnvelope({
      'action': 'msg-read',
      'id': messageId,
    });
  }

  void sendTypingStatus(bool isTyping) {
    _sendSignalEnvelope({
      'action': 'typing',
      'isTyping': isTyping,
    });
  }

  void sendReaction(String messageId, String emoji) {
    db.addReaction(messageId, emoji);
    _sendSignalEnvelope({
      'action': 'reaction',
      'messageId': messageId,
      'emoji': emoji,
    });
  }

  void editChatMessage(String messageId, String newText) {
    db.editMessage(messageId, newText);
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
          'type': 'edit-msg',
          'messageId': messageId,
          'newText': newText,
        })));
      } catch (_) {}
    }
    _sendSignalEnvelope({
      'action': 'edit-msg',
      'messageId': messageId,
      'newText': newText,
    });
  }

  void deleteMessage(String messageId) {
    db.deleteMessage(messageId);
    _sendSignalEnvelope({
      'action': 'delete-msg',
      'messageId': messageId,
    });
  }

  // --- TWO-WAY CALL SIGNALING ---
  Future<void> requestCall({required bool isVideo}) async {
    await _prepareLocalMedia(video: isVideo, audio: true);
    _sendSignalEnvelope({
      'action': 'call-request',
      'isVideo': isVideo,
    });
  }

  Future<void> acceptIncomingCall({required bool isVideo}) async {
    await _prepareLocalMedia(video: isVideo, audio: true);
    _sendSignalEnvelope({
      'action': 'call-accept',
      'isVideo': isVideo,
    });
  }

  void declineIncomingCall() {
    _sendSignalEnvelope({'action': 'call-decline'});
  }

  void cancelOutgoingCall() {
    _sendSignalEnvelope({'action': 'call-cancel'});
    endCall();
  }

  Future<void> _prepareLocalMedia({required bool video, required bool audio}) async {
    if (_peerConnection == null) return;

    try {
      if (localStream != null) {
        localStream!.getTracks().forEach((t) => t.stop());
      }

      final mediaConstraints = <String, dynamic>{
        'audio': audio,
        'video': video ? {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
          'frameRate': {'ideal': 24},
        } : false,
      };

      try {
        await localRenderer.initialize();
        await remoteRenderer.initialize();
      } catch (_) {}

      localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = localStream;

      for (var track in localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, localStream!);
      }

      isCalling = true;
      isVideoEnabled = video;
      isAudioEnabled = audio;
      _callStateController.add(true);
    } catch (e) {
      errorMessage = 'تعذر تشغيل الكاميرا/الميكروفون: $e';
    }
  }

  Future<void> toggleScreenShare() async {
    if (_peerConnection == null) return;

    try {
      if (!isScreenSharing) {
        final screenStream = await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
          'video': true,
          'audio': false,
        });
        if (screenStream.getVideoTracks().isNotEmpty) {
          final screenTrack = screenStream.getVideoTracks()[0];
          localRenderer.srcObject = screenStream;
          final senders = await _peerConnection!.getSenders();
          for (var sender in senders) {
            if (sender.track?.kind == 'video') {
              await sender.replaceTrack(screenTrack);
            }
          }
          isScreenSharing = true;
          _callStateController.add(true);
        }
      } else {
        if (localStream != null && localStream!.getVideoTracks().isNotEmpty) {
          final cameraTrack = localStream!.getVideoTracks()[0];
          localRenderer.srcObject = localStream;
          final senders = await _peerConnection!.getSenders();
          for (var sender in senders) {
            if (sender.track?.kind == 'video') {
              await sender.replaceTrack(cameraTrack);
            }
          }
          isScreenSharing = false;
          _callStateController.add(true);
        }
      }
    } catch (_) {}
  }

  Future<void> _initWebRTC() async {
    try {
      final config = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
          {'urls': 'stun:stun3.l.google.com:19302'},
          {'urls': 'stun:stun4.l.google.com:19302'},
          {'urls': 'stun:stun.cloudflare.com:3478'},
          {'urls': 'stun:global.stun.twilio.com:3478'},
          {'urls': 'stun:stun.services.mozilla.com'},
          {
            'urls': [
              'turn:openrelay.metered.ca:80',
              'turn:openrelay.metered.ca:443',
              'turn:openrelay.metered.ca:443?transport=tcp',
            ],
            'username': 'openrelay',
            'credential': 'openrelay',
          },
        ],
        'sdpSemantics': 'unified-plan',
        'iceCandidatePoolSize': 10,
      };

      _peerConnection = await createPeerConnection(config);

      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate.candidate != null) {
          _sendSignalEnvelope({
            'action': 'candidate',
            'sessionId': sessionId,
            'role': role == P2PRole.host ? 'host' : 'guest',
            'payload': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          });
        }
      };

      // Handle Remote Tracks in Unified-Plan
      _peerConnection!.onTrack = (RTCTrackEvent event) async {
        if (event.streams.isNotEmpty) {
          remoteStream = event.streams[0];
        } else {
          remoteStream ??= await createLocalMediaStream('remote_stream');
          remoteStream!.addTrack(event.track);
        }
        remoteRenderer.srcObject = remoteStream;
        isCalling = true;
        _callStateController.add(true);
      };

      _peerConnection!.onAddStream = (stream) {
        remoteStream = stream;
        remoteRenderer.srcObject = remoteStream;
        isCalling = true;
        _callStateController.add(true);
      };

      _peerConnection!.onConnectionState = (s) {
        if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _updateState(P2PState.connected);
        }
      };

      _peerConnection!.onDataChannel = (channel) {
        _setupDataChannel(channel);
      };
    } catch (e) {
      errorMessage = 'فشل تهيئة WebRTC: $e';
    }
  }

  void _setupDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    if (_dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _updateState(P2PState.connected);
    }

    _dataChannel!.onDataChannelState = (s) {
      if (s == RTCDataChannelState.RTCDataChannelOpen) {
        _updateState(P2PState.connected);
      }
    };

    _dataChannel!.onMessage = (data) {
      if (data.isBinary) return;
      try {
        final payload = jsonDecode(data.text);
        if (payload['type'] == 'chat') {
          final id = payload['id'] ?? FlutterCryptoEngine.generateSessionId();
          _receiveIncomingChatMessage(id, payload['text']);
          _sendSignalEnvelope({'action': 'msg-delivered', 'id': id});
        } else if (payload['type'] == 'draw') {
          _drawEventController.add(payload['event']);
        } else if (payload['type'] == 'typing') {
          _typingController.add(payload['isTyping'] == true);
        } else if (payload['type'] == 'reaction') {
          db.addReaction(payload['messageId'], payload['emoji']);
        } else if (payload['type'] == 'edit-msg') {
          db.editMessage(payload['messageId'], payload['newText']);
        }
      } catch (_) {}
    };
  }

  Future<void> _createOffer() async {
    try {
      if (_peerConnection == null) return;
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      await _peerConnection!.setLocalDescription(offer);

      _sendSignalEnvelope({
        'action': 'offer',
        'sessionId': sessionId,
        'role': role == P2PRole.host ? 'host' : 'guest',
        'payload': {
          'sdp': offer.sdp,
          'type': offer.type,
        },
      });
    } catch (_) {}
  }

  Future<void> sendChatMessage(String text) async {
    final id = FlutterCryptoEngine.generateSessionId();
    db.insertMessage(
      id: id,
      sender: 'self',
      text: text,
      status: 'sent',
    );

    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
          'type': 'chat',
          'id': id,
          'text': text,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        })));
      } catch (_) {}
    }

    _sendSignalEnvelope({
      'action': 'direct-chat',
      'sessionId': sessionId,
      'id': id,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void sendDrawEvent(Map<String, dynamic> event) {
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
          'type': 'draw',
          'event': event,
        })));
      } catch (_) {}
    }
    _sendSignalEnvelope({
      'action': 'draw',
      'sessionId': sessionId,
      'event': event,
    });
  }

  void endCall() {
    _sendSignalEnvelope({'action': 'call-end'});
    localStream?.getTracks().forEach((t) => t.stop());
    localStream = null;
    remoteStream = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    isCalling = false;
    isScreenSharing = false;
    _callStateController.add(false);
  }

  void toggleMic() {
    if (localStream != null) {
      isAudioEnabled = !isAudioEnabled;
      for (final track in localStream!.getAudioTracks()) {
        track.enabled = isAudioEnabled;
      }
    }
  }

  void toggleCamera() {
    if (localStream != null) {
      isVideoEnabled = !isVideoEnabled;
      for (final track in localStream!.getVideoTracks()) {
        track.enabled = isVideoEnabled;
      }
    }
  }

  void switchCamera() {
    if (localStream != null && localStream!.getVideoTracks().isNotEmpty) {
      Helper.switchCamera(localStream!.getVideoTracks()[0]);
    }
  }

  Future<void> panicDestroy() async {
    _pingTimer?.cancel();
    endCall();

    try {
      await MobileBackgroundHandler.stopForegroundService();
    } catch (_) {}

    try {
      await _inAppServerSubscription?.cancel();
      await inAppServer.stop();
    } catch (_) {}

    try {
      await _signalingSubscription?.cancel();
      _signalingSubscription = null;
      _dataChannel?.close();
      _peerConnection?.close();
      _signalingChannel?.sink.close();
    } catch (_) {}

    db.wipeAndDestroy();
    sessionId = null;
    preSharedKey = null;
    role = null;
    isUsingInAppServer = false;
    statusMessage = 'خامل';
    _updateState(P2PState.idle);
  }

  void _updateState(P2PState newState) {
    state = newState;
    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(newState);
    }
  }
}
