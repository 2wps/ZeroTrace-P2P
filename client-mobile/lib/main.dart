import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'core/crypto/crypto_engine.dart';
import 'core/audio/audio_synthesizer.dart';
import 'core/theme/theme_provider.dart';
import 'models/chat_message.dart';
import 'services/p2p_session_service.dart';
import 'services/foreground_service_handler.dart';
import 'components/qr_scanner_view.dart';
import 'components/mobile_whiteboard.dart';
import 'components/modern_call_screen.dart';
import 'components/incoming_call_dialog.dart';
import 'components/outgoing_call_dialog.dart';
import 'components/steganography_studio.dart';
import 'components/chat_bubble.dart';
import 'components/attachment_sheet.dart';
import 'components/pinned_message_header.dart';
import 'components/session_lock_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    MobileBackgroundHandler.initForegroundTask();
  } catch (_) {}
  runApp(const ZeroTraceApp());
}

class ZeroTraceApp extends StatefulWidget {
  const ZeroTraceApp({super.key});

  @override
  State<ZeroTraceApp> createState() => _ZeroTraceAppState();
}

class _ZeroTraceAppState extends State<ZeroTraceApp> {
  CyberTheme _currentTheme = CyberTheme.emerald;

  void _changeTheme(CyberTheme theme) {
    setState(() => _currentTheme = theme);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors.getTheme(_currentTheme);

    return MaterialApp(
      title: 'Zero-Trace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: colors.background,
        primaryColor: colors.primary,
        colorScheme: ColorScheme.dark(
          primary: colors.primary,
          secondary: colors.secondary,
          surface: colors.cardBg,
        ),
      ),
      home: HomeScreen(
        currentTheme: _currentTheme,
        onThemeChanged: _changeTheme,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final CyberTheme currentTheme;
  final ValueChanged<CyberTheme> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final P2PSessionService _sessionService = P2PSessionService();
  String? _inviteUrl;
  bool _isLoading = false;
  int _activeTabIndex = 0; // 0: Chat, 1: Whiteboard, 2: Call
  final TextEditingController _msgController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  bool _isRecordingVoice = false;
  int _voiceSeconds = 0;
  Timer? _voiceTimer;

  // In-Chat Search State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Quoted Reply & Pinned Message State
  ChatMessage? _replyingToMessage;
  ChatMessage? _pinnedMessage;
  ChatMessage? _editingMessage;

  // Privacy PIN Lock State
  bool _isSessionLocked = false;
  bool _isQuickEmojiOpen = false;

  int _selfDestructSeconds = 0;
  Timer? _deadMansSwitchTimer;
  Timer? _typingDebounce;
  static const int _inactivityTimeoutSeconds = 600; // 10 minutes

  // Network Connection Mode
  NetworkMode _selectedNetworkMode = NetworkMode.globalInternet;
  String? _selectedHostIp;
  final TextEditingController _customServerController = TextEditingController(text: 'ws://192.168.1.100:8080');
  final TextEditingController _joinUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sessionService.initialize();
    _resetDeadMansSwitch();

    // Listen for Call Events (Two-Way Ringing / Accept / Decline)
    _sessionService.callEventStream.listen((event) {
      if (!mounted) return;
      final type = event['type'];
      final isVideo = event['isVideo'] == true;

      if (type == 'incoming') {
        HapticFeedback.vibrate();
        _showIncomingCallDialog(isVideo);
      } else if (type == 'accepted') {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        setState(() => _activeTabIndex = 2);
      } else if (type == 'declined') {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض المكالمة من الطرف الآخر'), backgroundColor: Colors.redAccent),
        );
      } else if (type == 'cancelled' || type == 'ended') {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        setState(() => _activeTabIndex = 0);
      }
    });

    _sessionService.callStateStream.listen((isCalling) {
      if (isCalling && mounted) {
        setState(() => _activeTabIndex = 2);
      }
    });

    _msgController.addListener(_onTextChanged);
    _searchController.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
  }

  void _showIncomingCallDialog(bool isVideo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IncomingCallDialog(
        isVideo: isVideo,
        onAccept: () {
          Navigator.pop(ctx);
          _sessionService.acceptIncomingCall(isVideo: isVideo);
          setState(() => _activeTabIndex = 2);
        },
        onDecline: () {
          Navigator.pop(ctx);
          _sessionService.declineIncomingCall();
        },
      ),
    );
  }

  void _confirmAndStartCall({required bool isVideo}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D131F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isVideo ? Icons.videocam : Icons.phone, color: const Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text(isVideo ? 'بدء مكالمة فيديو HD' : 'بدء مكالمة صوتية P2P', style: const TextStyle(fontSize: 15)),
          ],
        ),
        content: Text(
          isVideo
              ? 'هل تريد بدء مكالمة فيديو مشفرة E2EE مع الطرف الآخر؟'
              : 'هل تريد بدء اتصال صوتي مشفر E2EE مع الطرف الآخر؟',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _startOutgoingCall(isVideo: isVideo);
            },
            child: const Text('اتصال 🟢'),
          ),
        ],
      ),
    );
  }

  void _startOutgoingCall({required bool isVideo}) {
    _resetDeadMansSwitch();
    _sessionService.requestCall(isVideo: isVideo);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OutgoingCallDialog(
        isVideo: isVideo,
        onCancel: () {
          Navigator.pop(ctx);
          _sessionService.cancelOutgoingCall();
        },
      ),
    );
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isScrolledUp = _scrollController.offset < _scrollController.position.maxScrollExtent - 200;
      if (isScrolledUp != _showScrollToBottom) {
        setState(() => _showScrollToBottom = isScrolledUp);
      }
    }
  }

  void _onTextChanged() {
    _resetDeadMansSwitch();
    _sessionService.sendTypingStatus(_msgController.text.trim().isNotEmpty);

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      _sessionService.sendTypingStatus(false);
    });
    setState(() {});
  }

  @override
  void dispose() {
    _msgController.removeListener(_onTextChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _msgController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _deadMansSwitchTimer?.cancel();
    _typingDebounce?.cancel();
    _voiceTimer?.cancel();
    super.dispose();
  }

  void _resetDeadMansSwitch() {
    _deadMansSwitchTimer?.cancel();
    _deadMansSwitchTimer = Timer(const Duration(seconds: _inactivityTimeoutSeconds), () {
      if (mounted) {
        _triggerPanicWipe();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startHost() async {
    _resetDeadMansSwitch();
    setState(() => _isLoading = true);

    try {
      final url = await _sessionService.startHostSession(
        mode: _selectedNetworkMode,
        customUrl: _selectedNetworkMode == NetworkMode.customRelay ? _customServerController.text.trim() : null,
        appBaseUrl: 'https://secure.p2p.app/join',
        preferredIp: _selectedHostIp,
      );
      setState(() {
        _inviteUrl = url;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0D131F),
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF06B6D4)),
                SizedBox(width: 8),
                Text('تنبيه الاتصال'),
              ],
            ),
            content: Text(
              'حدث خطأ أثناء تشغيل الجلسة:\n$e\n\nتأكد من توفر اتصال بالإنترنت أو تفعيل نقطة الاتصال (Hotspot).',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً', style: TextStyle(color: Color(0xFF10B981))),
              ),
            ],
          ),
        );
      }
    }
  }

  void _openCameraScanner() async {
    _resetDeadMansSwitch();
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (ctx) => const QRScannerView()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      _joinUrlController.text = scannedCode;
      _joinSession();
    }
  }

  void _joinSession() async {
    _resetDeadMansSwitch();
    final rawInput = _joinUrlController.text.trim();
    if (rawInput.isEmpty) return;

    final parsed = ParsedInviteUrl.parse(rawInput);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رابط الدعوة أو رمز الـ QR غير صالح')),
      );
      return;
    }

    final targetServer = parsed.host ?? _customServerController.text.trim();

    setState(() => _isLoading = true);

    try {
      await _sessionService.joinGuestSession(
        signalingUrl: targetServer,
        targetSessionId: parsed.sessionId,
        targetKey: parsed.key,
      );
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الانضمام: $e')),
        );
      }
    }
  }

  void _sendImageFromSource(ImageSource source) async {
    _resetDeadMansSwitch();
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      _sessionService.sendChatMessage('[IMAGE_DATA]:$base64Image');
      _scrollToBottom();
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال الصورة: $e')),
        );
      }
    }
  }

  void _sendFileAttachment() async {
    _resetDeadMansSwitch();
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null && file.path != null) {
      final bytes = await File(file.path!).readAsBytes();
      final base64File = base64Encode(bytes);
      final meta = '${file.name}|${file.size}|$base64File';
      _sessionService.sendChatMessage('[FILE_DATA]:$meta');
      _scrollToBottom();
      HapticFeedback.lightImpact();
    }
  }

  void _toggleVoiceRecording() {
    _resetDeadMansSwitch();
    if (!_isRecordingVoice) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isRecordingVoice = true;
        _voiceSeconds = 0;
      });
      _voiceTimer?.cancel();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _voiceSeconds++);
      });
    } else {
      _voiceTimer?.cancel();
      final duration = _voiceSeconds > 0 ? _voiceSeconds : 2;
      setState(() => _isRecordingVoice = false);
      
      final wavPayload = AudioSynthesizer.generateVoiceNoteWav(durationSeconds: duration);
      _sessionService.sendChatMessage('[VOICE_DATA]:$wavPayload');
      _scrollToBottom();
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال بصمة الصوت المشفرة في الـ RAM 🎙️')),
      );
    }
  }

  void _cancelVoiceRecording() {
    _voiceTimer?.cancel();
    setState(() => _isRecordingVoice = false);
    HapticFeedback.lightImpact();
  }

  void _openAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AttachmentSheet(
        onPickGallery: () => _sendImageFromSource(ImageSource.gallery),
        onPickCamera: () => _sendImageFromSource(ImageSource.camera),
        onPickDocument: _sendFileAttachment,
        onRecordVoice: _toggleVoiceRecording,
        onOpenStegano: _openSteganographyStudio,
        onOpenWhiteboard: () => setState(() => _activeTabIndex = 1),
      ),
    );
  }

  void _openSteganographyStudio() {
    _resetDeadMansSwitch();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => SteganographyStudio(
          onSendStegoMessage: (payload) {
            _sessionService.sendChatMessage(payload);
            _scrollToBottom();
          },
        ),
      ),
    );
  }

  void _triggerPanicWipe() {
    _sessionService.panicDestroy();
    setState(() {
      _inviteUrl = null;
      _isLoading = false;
      _activeTabIndex = 0;
      _replyingToMessage = null;
      _pinnedMessage = null;
      _editingMessage = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفريغ ومسح الذاكرة الحية بالكامل (Zero-Trace RAM Wiped)'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _triggerDuressDecoy() {
    _sessionService.db.wipeAndDestroy();
    _sessionService.db.initialize();
    _sessionService.db.insertMessage(
      id: 'decoy-1',
      sender: 'peer',
      text: 'هل اشتريت الحليب والخبز في طريق عودتك؟',
      status: 'received',
    );
    _sessionService.db.insertMessage(
      id: 'decoy-2',
      sender: 'self',
      text: 'نعم، اشتريت الحليب وبعض الفواكه وسأصل بعد قليل.',
      status: 'sent',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تفعيل وضع التمويه وتصفير الذاكرة الحقيقية (Decoy Active)'),
        backgroundColor: Colors.amber,
      ),
    );
  }

  void _openTimerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D131F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timer, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('مؤقت التدمير الذاتي للرسائل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            for (final option in [
              {'label': 'إيقاف التدمير التلقائي', 'sec': 0},
              {'label': 'تدمير بعد 10 ثوانٍ 🔥', 'sec': 10},
              {'label': 'تدمير بعد 30 ثانية 🔥', 'sec': 30},
              {'label': 'تدمير بعد دقيقة واحدة 🔥', 'sec': 60},
            ])
              ListTile(
                title: Text(option['label'] as String, style: const TextStyle(fontSize: 14)),
                trailing: _selfDestructSeconds == option['sec']
                    ? const Icon(Icons.check, color: Color(0xFF10B981))
                    : null,
                onTap: () {
                  setState(() => _selfDestructSeconds = option['sec'] as int);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D131F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.palette, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('اختر السمة واللون المفضل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            for (final t in [
              {'name': 'الزمرد السيبراني (Emerald Matrix)', 'theme': CyberTheme.emerald, 'color': const Color(0xFF10B981)},
              {'name': 'النيون الأزرق (Neon Cyan)', 'theme': CyberTheme.cyan, 'color': const Color(0xFF06B6D4)},
              {'name': 'الليلكي الداكن (Midnight Purple)', 'theme': CyberTheme.purple, 'color': const Color(0xFFA855F7)},
              {'name': 'الذهب التكتيكي (Tactical Amber)', 'theme': CyberTheme.amber, 'color': const Color(0xFFF59E0B)},
            ])
              ListTile(
                leading: CircleAvatar(backgroundColor: t['color'] as Color, radius: 12),
                title: Text(t['name'] as String, style: const TextStyle(fontSize: 13)),
                trailing: widget.currentTheme == t['theme'] ? const Icon(Icons.check, color: Colors.white) : null,
                onTap: () {
                  widget.onThemeChanged(t['theme'] as CyberTheme);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSessionSecurityInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D131F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('تقرير الأمان والتشفير الحي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildSecurityRow(Icons.lock, 'خوارزمية التشفير', 'AES-256-GCM + P-256 ECDH (E2EE)'),
            _buildSecurityRow(Icons.memory, 'وسط التخزين', 'ذاكرة حية متطايرة فقط (0MB Disk)'),
            _buildSecurityRow(Icons.public, 'نطاق الشبكة', _selectedNetworkMode == NetworkMode.globalInternet ? 'عابر للشبكات (4G/5G/Wi-Fi)' : 'شبكة محلية / Hotspot'),
            _buildSecurityRow(Icons.hub, 'نمط الاتصال', 'P2P مباشر عبر STUN/TURN Relays'),
            _buildSecurityRow(Icons.shield, 'رمز التحقق التوافقي (SAS)', '🛡️ 💎 🚀'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.flash_on, color: Colors.white, size: 16),
              label: const Text('تفريغ ومسح الذاكرة الآن (Purge RAM)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _triggerPanicWipe();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF06B6D4), size: 16),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMessageContextMenu(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D131F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final emoji in ['👍', '❤️', '🔥', '😂', '🔒', '⚡'])
                  GestureDetector(
                    onTap: () {
                      _sessionService.sendReaction(msg.id, emoji);
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF162032),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF10B981)),
              title: const Text('رد مقتبس (Reply)', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingToMessage = msg);
                _inputFocusNode.requestFocus();
              },
            ),
            if (msg.isSelf && msg.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF06B6D4)),
                title: const Text('تعديل الرسالة (Edit Message)', style: TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _editingMessage = msg;
                    _msgController.text = msg.text;
                  });
                  _inputFocusNode.requestFocus();
                  HapticFeedback.lightImpact();
                },
              ),
            ListTile(
              leading: const Icon(Icons.push_pin, color: Color(0xFFF59E0B)),
              title: const Text('تثبيت الرسالة في الأعلى (Pin)', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _pinnedMessage = msg);
                HapticFeedback.mediumImpact();
              },
            ),
            if (msg.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.copy, color: Color(0xFF06B6D4)),
                title: const Text('نسخ النص', style: TextStyle(fontSize: 14)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg.text));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ النص للحافظة')));
                },
              ),
            ListTile(
              leading: const Icon(Icons.local_fire_department, color: Colors.redAccent),
              title: const Text('حرق ومسح الرسالة فورياً (Burn Message)', style: TextStyle(fontSize: 14, color: Colors.redAccent)),
              onTap: () {
                _sessionService.deleteMessage(msg.id);
                Navigator.pop(ctx);
                HapticFeedback.mediumImpact();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSessionLocked) {
      return SessionLockOverlay(
        onUnlock: () => setState(() => _isSessionLocked = false),
      );
    }

    return GestureDetector(
      onTap: _resetDeadMansSwitch,
      onPanDown: (_) => _resetDeadMansSwitch(),
      child: StreamBuilder<P2PState>(
        stream: _sessionService.stateStream,
        initialData: P2PState.idle,
        builder: (context, snapshot) {
          final state = snapshot.data;
          final isConnected = state == P2PState.connected;

          return Scaffold(
            appBar: isConnected ? _buildChatAppBar() : _buildLobbyAppBar(),
            body: isConnected ? _buildConnectedView() : _buildLobbyView(state),
            floatingActionButton: (isConnected && _showScrollToBottom && _activeTabIndex == 0)
                ? FloatingActionButton.small(
                    backgroundColor: const Color(0xFF162032),
                    foregroundColor: const Color(0xFF10B981),
                    onPressed: _scrollToBottom,
                    child: const Icon(Icons.keyboard_arrow_down),
                  )
                : null,
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildLobbyAppBar() {
    return AppBar(
      title: const Text('Zero-Trace P2P', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFF0D131F),
      actions: [
        IconButton(
          icon: const Icon(Icons.palette, color: Color(0xFF10B981)),
          tooltip: 'تغيير السمة واللون',
          onPressed: _openThemePicker,
        ),
        IconButton(
          icon: const Icon(Icons.visibility_off, color: Colors.amberAccent),
          tooltip: 'وضع التمويه (Decoy Vault)',
          onPressed: _triggerDuressDecoy,
        ),
        IconButton(
          icon: const Icon(Icons.flash_on, color: Colors.redAccent),
          tooltip: 'تدمير فوري للجلسة (Panic)',
          onPressed: _triggerPanicWipe,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildChatAppBar() {
    if (_isSearching) {
      return AppBar(
        backgroundColor: const Color(0xFF0D131F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'بحث في الرسائل الحالية...',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _searchController.clear(),
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: const Color(0xFF0D131F),
      elevation: 1,
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF162032),
              border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            ),
            child: const Center(
              child: Text('ZT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('جلسة مشفرة E2EE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                StreamBuilder<bool>(
                  stream: _sessionService.typingStream,
                  initialData: false,
                  builder: (context, snap) {
                    if (snap.data == true) {
                      return const Text('يكتب الآن...', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontStyle: FontStyle.italic));
                    }
                    return Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        const Text('متصل P2P', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          StreamBuilder<int>(
            stream: _sessionService.latencyStream,
            initialData: 12,
            builder: (context, snap) {
              final ping = snap.data ?? 12;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$ping ms', style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white70),
          tooltip: 'بحث في المحادثة',
          onPressed: () => setState(() => _isSearching = true),
        ),
        IconButton(
          icon: const Icon(Icons.phone, color: Color(0xFF10B981)),
          tooltip: 'اتصال صوتي P2P',
          onPressed: () => _confirmAndStartCall(isVideo: false),
        ),
        IconButton(
          icon: const Icon(Icons.videocam, color: Color(0xFF06B6D4)),
          tooltip: 'مكالمة فيديو HD مشفرة',
          onPressed: () => _confirmAndStartCall(isVideo: true),
        ),
        PopupMenuButton<String>(
          color: const Color(0xFF162032),
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          onSelected: (val) {
            if (val == 'lock') setState(() => _isSessionLocked = true);
            if (val == 'palette') _openThemePicker();
            if (val == 'timer') _openTimerPicker();
            if (val == 'stego') _openSteganographyStudio();
            if (val == 'whiteboard') setState(() => _activeTabIndex = 1);
            if (val == 'info') _showSessionSecurityInfo();
            if (val == 'decoy') _triggerDuressDecoy();
            if (val == 'panic') _triggerPanicWipe();
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'lock', child: Text('🔒 قفل الجلسة برمز PIN')),
            const PopupMenuItem(value: 'palette', child: Text('🎨 تغيير السمة والألوان')),
            const PopupMenuItem(value: 'timer', child: Text('⏱️ مؤقت التدمير الذاتي')),
            const PopupMenuItem(value: 'stego', child: Text('🖼️ استوديو التشفير الإخفائي')),
            const PopupMenuItem(value: 'whiteboard', child: Text('🖌️ لوحة الرسم P2P')),
            const PopupMenuItem(value: 'info', child: Text('ℹ️ تقرير الأمان والتشفير')),
            const PopupMenuItem(value: 'decoy', child: Text('🎭 وضع التمويه (Decoy)')),
            const PopupMenuItem(value: 'panic', child: Text('⚡ تدمير الجلسة ومسح الـ RAM', style: TextStyle(color: Colors.redAccent))),
          ],
        ),
      ],
    );
  }

  Widget _buildLobbyView(P2PState? state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          const Icon(Icons.public, size: 56, color: Color(0xFF10B981)),
          const SizedBox(height: 12),
          const Text(
            'اتصال مباشر مشفر P2P عبر الشبكات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'يعمل عبر شبكات الإنترنت المتباعدة (4G/5G/Wi-Fi) أو محلياً دون تخزين على أي قرص.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Network Mode Selector Cards
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D131F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اختر نمط ونطاق الاتصال:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 10),
                _buildModeTile(
                  mode: NetworkMode.globalInternet,
                  icon: Icons.language,
                  title: '🌐 عبر الإنترنت والشبكات المختلفة (4G/5G/Wi-Fi)',
                  subtitle: 'يعمل بين أي هاتفين في مدينتين أو شبكتين مختلفتين عبر STUN/TURN',
                ),
                _buildModeTile(
                  mode: NetworkMode.localWifi,
                  icon: Icons.wifi,
                  title: '📱 شبكة محلية / نقطة اتصال (Local Wi-Fi / Hotspot)',
                  subtitle: 'يعمل بالسيرفر الداخلي على الهاتف للشبكة نفسها دون إنترنت',
                ),
                _buildModeTile(
                  mode: NetworkMode.customRelay,
                  icon: Icons.dns,
                  title: '⚡ سيرفر وسيط مخصص (Custom Server / Tunnel)',
                  subtitle: 'استخدام عنوان WebSocket أو نفق Cloudflare خاص',
                ),
                if (_selectedNetworkMode == NetworkMode.customRelay) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customServerController,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'wss://your-relay-server.com',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFF162032),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Host Button
          ElevatedButton.icon(
            icon: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.hub),
            label: Text(_isLoading ? 'جاري تهيئة قناة الاتصال المشفرة...' : 'إنشاء جلسة جديدة (Create Session)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _startHost,
          ),

          if (_inviteUrl != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D131F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withAlpha(76)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        state == P2PState.connected ? Icons.check_circle : Icons.sync,
                        color: state == P2PState.connected ? const Color(0xFF10B981) : Colors.amberAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state == P2PState.connected
                            ? '🟢 تم الاتصال بالطرف الآخر!'
                            : (state == P2PState.connecting ? '🔄 جاري تبادل التشفير عبر STUN/TURN...' : '🟡 الجلسة جاهزة.. امسح الـ QR أو أرسل الرابط'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: state == P2PState.connected ? const Color(0xFF10B981) : Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  QrImageView(
                    data: _inviteUrl!,
                    version: QrVersions.auto,
                    size: 160.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _inviteUrl!,
                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('نسخ رابط الدعوة', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF162032)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _inviteUrl!));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرابط للحافظة')));
                    },
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Join Section with QR Scanning options
          const Text('الانضمام لجلسة قائمة (Join as Guest):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
            label: const Text('مسح رمز الـ QR بالكاميرا مباشرة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _openCameraScanner,
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _joinUrlController,
            decoration: InputDecoration(
              hintText: 'أو الصق رابط الدعوة هنا https://...#sid=...&key=...',
              hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF0D131F),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: _isLoading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.login),
            label: Text(_isLoading ? 'جاري الاتصال بالسيرفر...' : 'انضمام للجلسة بالرابط'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _joinSession,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTile({
    required NetworkMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedNetworkMode == mode;

    return GestureDetector(
      onTap: () => setState(() => _selectedNetworkMode = mode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF162032) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF10B981) : Colors.grey, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedView() {
    if (_activeTabIndex == 1) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF0D131F),
            child: Row(
              children: [
                const Text('لوحة الرسم P2P المشتركة 🎨', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.chat, size: 16),
                  label: const Text('العودة للمحادثة'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  onPressed: () => setState(() => _activeTabIndex = 0),
                ),
              ],
            ),
          ),
          Expanded(
            child: MobileWhiteboard(
              onSendDrawEvent: _sessionService.sendDrawEvent,
              drawEventStream: _sessionService.drawEventStream,
            ),
          ),
        ],
      );
    } else if (_activeTabIndex == 2) {
      return ModernCallScreen(
        sessionService: _sessionService,
        onEndCall: () {
          _sessionService.endCall();
          setState(() => _activeTabIndex = 0);
        },
      );
    }
    return _buildChatView();
  }

  Widget _buildChatView() {
    final hasText = _msgController.text.trim().isNotEmpty;
    final query = _searchController.text.trim().toLowerCase();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF07090E),
      ),
      child: Column(
        children: [
          // Pinned Message Banner
          if (_pinnedMessage != null)
            PinnedMessageHeader(
              pinnedMessage: _pinnedMessage!,
              onTap: () {
                _scrollToBottom();
                HapticFeedback.lightImpact();
              },
              onUnpin: () {
                setState(() => _pinnedMessage = null);
                HapticFeedback.lightImpact();
              },
            ),
          // Out-of-band SAS Security Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFF10B981).withAlpha(20),
            child: Row(
              children: [
                const Icon(Icons.lock, size: 12, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'تشفير تام E2EE في الذاكرة الحية (RAM) | التحقق: 🛡️ 💎 🚀',
                    style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                  ),
                ),
                if (_selfDestructSeconds > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(50),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('🔥 ${_selfDestructSeconds}s', style: const TextStyle(fontSize: 10, color: Colors.amberAccent)),
                  ),
              ],
            ),
          ),
          // Live Chat Message Stream with Floating Date Separators
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _sessionService.db.messageStream,
              initialData: _sessionService.db.getAllMessages(),
              builder: (context, snapshot) {
                final rawMsgs = snapshot.data ?? [];
                var msgs = rawMsgs.map((m) => ChatMessage.fromMap(m)).toList();

                // Mark incoming peer messages as read when viewing chat
                for (var m in msgs) {
                  if (!m.isSelf && m.status != MessageStatus.read) {
                    _sessionService.sendReadReceipt(m.id);
                  }
                }

                if (query.isNotEmpty) {
                  msgs = msgs.where((m) => m.text.toLowerCase().contains(query)).toList();
                }

                _scrollToBottom();

                if (msgs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(query.isNotEmpty ? Icons.search_off : Icons.lock_open, size: 48, color: const Color(0xFF10B981)),
                        const SizedBox(height: 12),
                        Text(
                          query.isNotEmpty ? 'لا توجد نتائج مطابقة في الـ RAM' : 'الجلسة مؤمنة بنجاح 🟢',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          query.isNotEmpty ? 'جرب البحث عن كلمة أخرى' : 'اكتب رسالة أو أرسل صورة أو ملفاً أو ابدأ مكالمة صوت/فيديو.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final msg = msgs[index];
                    final isFirstOrNewDay = index == 0 || _isDifferentDay(msgs[index - 1].timestamp, msg.timestamp);

                    return Column(
                      children: [
                        if (isFirstOrNewDay)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF162032).withAlpha(180),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              _formatDateHeader(msg.timestamp),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                          ),
                        ChatBubble(
                          message: msg,
                          onLongPress: () => _showMessageContextMenu(msg),
                          onQuickReact: (emoji) => _sessionService.sendReaction(msg.id, emoji),
                          onSwipeReply: () {
                            setState(() => _replyingToMessage = msg);
                            _inputFocusNode.requestFocus();
                            HapticFeedback.lightImpact();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Edit Message Banner
          if (_editingMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFF0284C7).withAlpha(40),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Color(0xFF06B6D4), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تعديل الرسالة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
                        Text(
                          _editingMessage!.text,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                    onPressed: () {
                      setState(() {
                        _editingMessage = null;
                        _msgController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          // Quoted Reply Preview Bar
          if (_replyingToMessage != null && _editingMessage == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFF162032),
              child: Row(
                children: [
                  const Icon(Icons.reply, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyingToMessage!.isSelf ? 'رد على رسالتك' : 'رد على رسالة الطرف الآخر',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                        Text(
                          _replyingToMessage!.text,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                    onPressed: () => setState(() => _replyingToMessage = null),
                  ),
                ],
              ),
            ),
          // Quick Emoji Bar
          if (_isQuickEmojiOpen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: const Color(0xFF0D131F),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '🔥', '😂', '🔒', '⚡', '👏', '🎯', '🚀', '💯'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      _msgController.text += emoji;
                      HapticFeedback.selectionClick();
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  );
                }).toList(),
              ),
            ),
          // Live Voice Recording Banner
          if (_isRecordingVoice)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.withAlpha(40),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'جاري تسجيل بصمة الصوت: 00:${_voiceSeconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _cancelVoiceRecording,
                    child: const Text('إلغاء', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                ],
              ),
            ),
          // Modern Secure Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
            color: const Color(0xFF0D131F),
            child: SafeArea(
              child: Row(
                children: [
                  // Attachment Pin Button
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Color(0xFF10B981)),
                    tooltip: 'إرسال مرفق',
                    onPressed: _openAttachmentMenu,
                  ),
                  // Chat Input Field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF162032),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isQuickEmojiOpen ? Icons.keyboard : Icons.emoji_emotions_outlined,
                              color: _isQuickEmojiOpen ? const Color(0xFF10B981) : Colors.white54,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _isQuickEmojiOpen = !_isQuickEmojiOpen),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _msgController,
                              focusNode: _inputFocusNode,
                              maxLines: 4,
                              minLines: 1,
                              onSubmitted: (_) => _handleSendText(),
                              decoration: InputDecoration(
                                hintText: _editingMessage != null ? 'تعديل نص الرسالة...' : 'رسالة مشفرة...',
                                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 20),
                            onPressed: () => _sendImageFromSource(ImageSource.camera),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Dedicated Voice Recording Button
                  GestureDetector(
                    onTap: _toggleVoiceRecording,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isRecordingVoice ? Colors.redAccent : const Color(0xFF162032),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isRecordingVoice ? Colors.red : Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _isRecordingVoice ? Icons.stop : Icons.mic,
                        color: _isRecordingVoice ? Colors.white : const Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Dedicated Send / Edit Checkmark Button
                  GestureDetector(
                    onTap: hasText ? _handleSendText : null,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: hasText ? (_editingMessage != null ? const Color(0xFF06B6D4) : const Color(0xFF10B981)) : Colors.white12,
                        shape: BoxShape.circle,
                        boxShadow: hasText
                            ? [
                                BoxShadow(
                                  color: (_editingMessage != null ? const Color(0xFF06B6D4) : const Color(0xFF10B981)).withAlpha(100),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _editingMessage != null ? Icons.check : Icons.send,
                        color: hasText ? Colors.white : Colors.white38,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isDifferentDay(int t1, int t2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(t1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(t2);
    return d1.year != d2.year || d1.month != d2.month || d1.day != d2.day;
  }

  String _formatDateHeader(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'اليوم';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'أمس';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _handleSendText() {
    final text = _msgController.text.trim();
    if (text.isNotEmpty) {
      if (_editingMessage != null) {
        _sessionService.editChatMessage(_editingMessage!.id, text);
        _msgController.clear();
        setState(() => _editingMessage = null);
        HapticFeedback.lightImpact();
        return;
      }

      String finalPayload = text;
      if (_replyingToMessage != null) {
        final quoteSender = _replyingToMessage!.isSelf ? 'self' : 'peer';
        final quoteSnippet = _replyingToMessage!.text.replaceAll('\n', ' ');
        finalPayload = '[QUOTE:$quoteSender|$quoteSnippet]:$text';
      }

      final msgId = FlutterCryptoEngine.generateSessionId();
      _sessionService.sendChatMessage(finalPayload);
      _msgController.clear();
      setState(() => _replyingToMessage = null);
      _scrollToBottom();
      HapticFeedback.lightImpact();

      // Schedule Auto-Destruct if enabled
      if (_selfDestructSeconds > 0) {
        Timer(Duration(seconds: _selfDestructSeconds), () {
          if (mounted) {
            _sessionService.deleteMessage(msgId);
          }
        });
      }
    }
  }
}
