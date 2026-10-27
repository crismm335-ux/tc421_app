// Escolhe o cliente MQTT certo: TCP com TLS no celular e no PC,
// WebSocket seguro no navegador (versão web, usada no iPhone).
export 'mqtt_factory_io.dart' if (dart.library.js_interop) 'mqtt_factory_web.dart';
