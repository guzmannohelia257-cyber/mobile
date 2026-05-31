import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../config/api_config.dart';

enum WsState { disconnected, connecting, connected, reconnecting }

class WsEvent {
  final String event;
  final Map<String, dynamic>? data;
  final String? channel;
  final String? detail;

  WsEvent({
    required this.event,
    this.data,
    this.channel,
    this.detail,
  });

  factory WsEvent.fromJson(Map<String, dynamic> json) => WsEvent(
        event: json['event'] as String? ?? 'unknown',
        data: json['data'] as Map<String, dynamic>?,
        channel: json['channel'] as String?,
        detail: json['detail'] as String?,
      );
}

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._();
  factory RealtimeService() => _instance;
  RealtimeService._();

  WebSocketChannel? _channel;
  String? _token;
  int _attempts = 0;
  Timer? _reconnectTimer;
  bool _disposed = false;

  final Set<String> _subscribed = {};

  final _eventsCtrl = StreamController<WsEvent>.broadcast();
  Stream<WsEvent> get events => _eventsCtrl.stream;

  final _stateCtrl = StreamController<WsState>.broadcast();
  Stream<WsState> get state => _stateCtrl.stream;
  WsState _state = WsState.disconnected;
  WsState get currentState => _state;

  void connect(String token) {
    _token = token;
    _disposed = false;
    _connect();
  }

  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    // El paquete `web_socket` rechaza códigos como 1001 (goingAway): exige
    // 1000 (normalClosure) o el rango 3000-4999. Usamos normalClosure.
    try {
      _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {
      // Si la conexión ya estaba caída, ignoramos.
    }
    _channel = null;
    _subscribed.clear();
    _updateState(WsState.disconnected);
  }

  void subscribe(String channel) {
    _subscribed.add(channel);
    _send({'action': 'subscribe', 'channel': channel});
  }

  void unsubscribe(String channel) {
    _subscribed.remove(channel);
    _send({'action': 'unsubscribe', 'channel': channel});
  }

  void ping() {
    _send({'action': 'ping'});
  }

  void _connect() {
    if (_token == null || _disposed) return;

    _updateState(_attempts == 0 ? WsState.connecting : WsState.reconnecting);

    final url = Uri.parse(
      '${ApiConfig.wsUrl}/ws?token=${Uri.encodeComponent(_token!)}',
    );

    try {
      _channel = WebSocketChannel.connect(url);
    } catch (_) {
      _scheduleReconnect();
      return;
    }

    _channel!.stream.listen(
      _onMessage,
      onError: (_) => _onClosed(null),
      onDone: () => _onClosed(_channel?.closeCode),
      cancelOnError: false,
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (_state == WsState.connected || _channel != null) {
        for (final ch in _subscribed) {
          _send({'action': 'subscribe', 'channel': ch});
        }
      }
    });
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final evt = WsEvent.fromJson(msg);
      if (evt.event == 'connected') {
        _attempts = 0;
        _updateState(WsState.connected);
      }
      _eventsCtrl.add(evt);
    } catch (_) {}
  }

  void _onClosed(int? code) {
    _channel = null;
    _updateState(WsState.disconnected);
    if (_disposed) return;
    if (code == 1008) {
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final delaySeconds = _attempts <= 0 ? 1 : (1 << _attempts);
    final delay = Duration(seconds: delaySeconds.clamp(1, 30));
    _attempts++;
    _updateState(WsState.reconnecting);
    _reconnectTimer = Timer(delay, _connect);
  }

  void _send(Object payload) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void _updateState(WsState s) {
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  void dispose() {
    disconnect();
    _eventsCtrl.close();
    _stateCtrl.close();
  }
}
