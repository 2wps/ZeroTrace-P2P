import 'dart:async';
import 'dart:convert';
import 'dart:io';

class InAppHostServer {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final StreamController<Map<String, dynamic>> _signalStream = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get signalStream => _signalStream.stream;
  int? get port => _server?.port;
  String? boundIp;
  List<String> availableIps = [];

  /// Starts the temporary in-app server directly on the mobile phone
  Future<String> start({int port = 8080}) async {
    await stop();

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    } catch (_) {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
    }

    _server!.listen((HttpRequest request) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        WebSocketTransformer.upgrade(request).then(_handleWebSocket);
      } else {
        request.response
          ..headers.contentType = ContentType.json
          ..headers.add('Access-Control-Allow-Origin', '*')
          ..headers.add('Access-Control-Allow-Headers', '*')
          ..write(jsonEncode({
            'status': 'running',
            'service': 'Zero-Trace Mobile Host',
            'connected_clients': _clients.length,
          }))
          ..close();
      }
    });

    availableIps = await getAllLocalIps();
    boundIp = availableIps.isNotEmpty ? availableIps.first : '127.0.0.1';
    return 'ws://$boundIp:${_server!.port}';
  }

  void _handleWebSocket(WebSocket ws) {
    _clients.add(ws);

    // Notify listeners that a peer connected at network level
    _signalStream.add({
      'action': 'peer-connected',
      'clientsCount': _clients.length,
    });

    ws.listen(
      (data) {
        try {
          final msg = jsonDecode(data.toString());
          _signalStream.add(msg);

          // Broadcast signal to all other connected peers
          for (final client in _clients) {
            if (client != ws && client.readyState == WebSocket.open) {
              client.add(data.toString());
            }
          }
        } catch (_) {}
      },
      onDone: () {
        _clients.remove(ws);
        _signalStream.add({
          'action': 'peer-disconnected',
          'clientsCount': _clients.length,
        });
      },
      onError: (_) {
        _clients.remove(ws);
      },
    );
  }

  void broadcast(Map<String, dynamic> message) {
    final payload = jsonEncode(message);
    for (final client in _clients) {
      if (client.readyState == WebSocket.open) {
        client.add(payload);
      }
    }
  }

  /// Lists all actual Wi-Fi, Hotspot, and LAN IPv4 addresses on the phone
  static Future<List<String>> getAllLocalIps() async {
    final List<String> ips = [];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // Prioritize Wi-Fi and Hotspot interfaces (wlan, ap, swlan)
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('ap') || name.contains('rndis') || name.contains('eth')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback && !addr.address.startsWith('127.') && !ips.contains(addr.address)) {
              ips.add(addr.address);
            }
          }
        }
      }

      // Add remaining valid IPv4 addresses
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.') && !ips.contains(addr.address)) {
            ips.add(addr.address);
          }
        }
      }
    } catch (_) {}

    if (ips.isEmpty) ips.add('127.0.0.1');
    return ips;
  }

  /// Stops server and closes all sockets immediately (Zero-Trace)
  Future<void> stop() async {
    for (final client in _clients) {
      try {
        client.close(WebSocketStatus.normalClosure, 'Host terminated');
      } catch (_) {}
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    boundIp = null;
  }
}
