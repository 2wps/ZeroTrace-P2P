import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

class ParsedInviteUrl {
  final String sessionId;
  final String key;
  final String? host;

  ParsedInviteUrl({
    required this.sessionId,
    required this.key,
    this.host,
  });

  static ParsedInviteUrl? parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    String queryString = '';
    if (text.contains('#')) {
      queryString = text.substring(text.indexOf('#') + 1);
    } else if (text.contains('?')) {
      queryString = text.substring(text.indexOf('?') + 1);
    } else {
      queryString = text;
    }

    final params = Uri.splitQueryString(queryString);
    final sid = params['sid'];
    final key = params['key'];
    String? host = params['host'];

    if (sid == null || key == null || sid.isEmpty || key.isEmpty) {
      return null;
    }

    if (host != null && (host.contains('%3A') || host.contains('%2F'))) {
      try {
        host = Uri.decodeComponent(host);
      } catch (_) {}
    }

    return ParsedInviteUrl(
      sessionId: sid,
      key: key,
      host: host,
    );
  }
}

class FlutterCryptoEngine {
  static final _algorithm = AesGcm.with256bits();
  static final _ecdh = Ecdh.p256(length: 32);

  static String generateSessionSecret() {
    final random = Random.secure();
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64UrlEncode(bytes);
  }

  static String generateSessionId() {
    return const Uuid().v4();
  }

  static Future<EcKeyPair> generateKeyPair() async {
    return await _ecdh.newKeyPair();
  }

  static Future<Map<String, dynamic>> encryptPayload(
    SecretKey key,
    dynamic data,
  ) async {
    final jsonStr = data is String ? data : jsonEncode(data);
    final plainBytes = utf8.encode(jsonStr);

    final secretBox = await _algorithm.encrypt(
      plainBytes,
      secretKey: key,
    );

    return {
      'iv': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText + secretBox.mac.bytes),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static Future<dynamic> decryptPayload(
    SecretKey key,
    Map<String, dynamic> encrypted,
  ) async {
    final nonce = base64Decode(encrypted['iv']);
    final rawCipher = base64Decode(encrypted['ciphertext']);

    final cipherText = rawCipher.sublist(0, rawCipher.length - 16);
    final macBytes = rawCipher.sublist(rawCipher.length - 16);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clearBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: key,
    );

    final decodedStr = utf8.decode(clearBytes);
    try {
      return jsonDecode(decodedStr);
    } catch (_) {
      return decodedStr;
    }
  }

  static String createInviteUrl(String baseUrl, {
    required String sessionId,
    required String psk,
    String? host,
    String? fingerprint,
  }) {
    final uri = Uri.parse(baseUrl);
    final encodedHost = host != null ? Uri.encodeComponent(host) : '';
    final fragment = 'sid=$sessionId&key=$psk${host != null ? '&host=$encodedHost' : ''}${fingerprint != null ? '&fp=$fingerprint' : ''}';
    return uri.replace(fragment: fragment).toString();
  }

  static void memzero(Uint8List buffer) {
    final random = Random.secure();
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = random.nextInt(256);
    }
    buffer.fillRange(0, buffer.length, 0);
  }
}
