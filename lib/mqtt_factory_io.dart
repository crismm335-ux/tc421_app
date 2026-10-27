import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Android, iPhone (app instalado) e Windows: MQTT com TLS (HiveMQ Cloud: 8883).
MqttClient makeMqttClient(String host, String clientId, int port) {
  final c = MqttServerClient.withPort(host, clientId, port);
  c.secure = true;
  return c;
}

/// Porta usada nesta plataforma.
int mqttPortFor(int configured) => configured;
