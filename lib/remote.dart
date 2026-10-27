import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mqtt_factory.dart';

/// Acesso pela internet: o app e o ESP32 conversam por um servidor MQTT na
/// nuvem (por exemplo o HiveMQ Cloud, gratuito). Funciona de qualquer lugar.
///
/// Tópicos (iguais aos do programa do ESP32):
///   aqualight/<id>/status   estado completo do aquário (retido)
///   aqualight/<id>/online   1 = ESP32 ligado, 0 = caiu (retido)
///   aqualight/<id>/cmd      comando, no formato "/api/set?id=3&mode=1"
///   aqualight/<id>/tc/req   pacote para a luminária TC421
///   aqualight/<id>/tc/rep   resposta da luminária
class RemoteLink extends ChangeNotifier {
  String host = '';
  int port = 8883;
  String user = '';
  String password = '';
  String deviceId = '';

  MqttClient? _client;
  StreamSubscription? _sub;
  bool connecting = false;
  String status = 'Desligado';

  /// O ESP32 está ligado à internet agora?
  bool espOnline = false;

  /// Último estado que o ESP32 publicou.
  Map<String, dynamic>? lastStatus;
  DateTime? lastStatusAt;

  final StreamController<Map<String, dynamic>> _statusStream =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get statusUpdates => _statusStream.stream;

  final Map<String, Completer<Uint8List?>> _tcWaiting = {};
  int _tcSeq = 0;

  bool get configured =>
      host.isNotEmpty && user.isNotEmpty && password.isNotEmpty && deviceId.isNotEmpty;

  bool get connected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  /// Pronto para usar: servidor conectado e ESP32 respondendo.
  bool get ready => connected && espOnline;

  String _topic(String t) => 'aqualight/$deviceId/$t';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    host = p.getString('mqtt_host') ?? '';
    port = p.getInt('mqtt_port') ?? 8883;
    user = p.getString('mqtt_user') ?? '';
    password = p.getString('mqtt_pass') ?? '';
    deviceId = p.getString('mqtt_device') ?? '';
    if (configured) await connect();
    notifyListeners();
  }

  Future<void> save({
    required String host,
    required int port,
    required String user,
    required String password,
    required String deviceId,
  }) async {
    this.host = host.trim();
    this.port = port;
    this.user = user.trim();
    this.password = password;
    this.deviceId = deviceId.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString('mqtt_host', this.host);
    await p.setInt('mqtt_port', this.port);
    await p.setString('mqtt_user', this.user);
    await p.setString('mqtt_pass', this.password);
    await p.setString('mqtt_device', this.deviceId);
    disconnect();
    if (configured) await connect();
    notifyListeners();
  }

  Future<void> connect() async {
    if (!configured || connecting || connected) return;
    connecting = true;
    status = 'Conectando ao servidor...';
    notifyListeners();
    final clientId =
        'app-${deviceId}-${math.Random().nextInt(1 << 30).toRadixString(36)}';
    final c = makeMqttClient(host, clientId, mqttPortFor(port));
    c.setProtocolV311();
    c.keepAlivePeriod = 30;
    c.autoReconnect = true;
    c.logging(on: false);
    c.connectionMessage =
        MqttConnectMessage().withClientIdentifier(clientId).startClean();
    c.onConnected = _onConnected;
    c.onAutoReconnected = _onConnected;
    c.onDisconnected = () {
      status = 'Sem conexão com o servidor';
      notifyListeners();
    };
    _client = c;
    try {
      await c.connect(user, password);
    } catch (e) {
      status = 'Não conectou ao servidor. Confira o endereço, o usuário e a senha.';
      c.disconnect();
      _client = null;
    }
    connecting = false;
    if (connected) _onConnected();
    notifyListeners();
  }

  void _onConnected() {
    final c = _client;
    if (c == null) return;
    status = 'Conectado ao servidor';
    c.subscribe(_topic('status'), MqttQos.atLeastOnce);
    c.subscribe(_topic('online'), MqttQos.atLeastOnce);
    c.subscribe(_topic('tc/rep'), MqttQos.atMostOnce);
    _sub?.cancel();
    _sub = c.updates?.listen(_onMessages);
    notifyListeners();
  }

  void _onMessages(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final m in messages) {
      final payload = m.payload;
      if (payload is! MqttPublishMessage) continue;
      String text;
      try {
        text = utf8.decode(payload.payload.message.toList());
      } catch (_) {
        continue;
      }
      if (m.topic == _topic('online')) {
        espOnline = text == '1';
        notifyListeners();
      } else if (m.topic == _topic('status')) {
        try {
          final j = jsonDecode(text) as Map<String, dynamic>;
          lastStatus = j;
          lastStatusAt = DateTime.now();
          _statusStream.add(j);
        } catch (_) {}
      } else if (m.topic == _topic('tc/rep')) {
        final q = Uri.splitQueryString(text);
        final w = _tcWaiting.remove(q['n']);
        if (w != null && !w.isCompleted) {
          final hex = q['hex'] ?? '';
          w.complete(hex.isEmpty ? null : _fromHex(hex));
        }
      }
    }
  }

  void _publish(String topic, String text) {
    final c = _client;
    if (c == null || !connected) return;
    final b = MqttClientPayloadBuilder()..addUTF8String(text);
    c.publishMessage(topic, MqttQos.atLeastOnce, b.payload!);
  }

  /// Envia um comando ao ESP32 (mesmos caminhos da rede local).
  void command(String path, [Map<String, String>? query]) {
    final uri = Uri(path: path, queryParameters: (query == null || query.isEmpty) ? null : query);
    _publish(_topic('cmd'), uri.toString());
  }

  /// Manda um pacote para a TC421 pelo ESP32. Com [waitMs] > 0, espera a
  /// resposta da luminária (null se não veio).
  Future<Uint8List?> tcRequest(Uint8List packet, int waitMs, {String? ip}) async {
    if (!connected) return null;
    final id = '${++_tcSeq}';
    final query = <String, String>{
      'n': id,
      'w': '$waitMs',
      if (ip != null && ip.isNotEmpty) 'ip': ip,
      'hex': _toHex(packet),
    };
    if (waitMs <= 0) {
      _publish(_topic('tc/req'), Uri(queryParameters: query).query);
      return null;
    }
    final done = Completer<Uint8List?>();
    _tcWaiting[id] = done;
    _publish(_topic('tc/req'), Uri(queryParameters: query).query);
    // Ida e volta pela internet: dá mais tempo que na rede de casa.
    return done.future.timeout(Duration(milliseconds: waitMs + 4000), onTimeout: () {
      _tcWaiting.remove(id);
      return null;
    });
  }

  void disconnect() {
    _sub?.cancel();
    _sub = null;
    _client?.autoReconnect = false;
    _client?.disconnect();
    _client = null;
    espOnline = false;
    status = 'Desligado';
  }

  static String _toHex(Uint8List b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _fromHex(String h) {
    final out = Uint8List(h.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  @override
  void dispose() {
    disconnect();
    _statusStream.close();
    super.dispose();
  }
}
