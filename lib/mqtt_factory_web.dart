import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

/// Navegador: MQTT por WebSocket seguro. No HiveMQ Cloud é a porta 8884,
/// caminho /mqtt (a porta 8883 não funciona em navegador).
MqttClient makeMqttClient(String host, String clientId, int port) {
  return MqttBrowserClient.withPort('wss://$host/mqtt', clientId, 8884);
}

/// Porta usada nesta plataforma.
int mqttPortFor(int configured) => 8884;
