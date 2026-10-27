import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// No Android, pede para o sistema não descartar os pacotes de broadcast do
/// Wi-Fi (é por broadcast que a TC421 responde). Nas outras plataformas não
/// faz nada.
Future<void> acquireBroadcastLock() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    await const MethodChannel('aqua/net').invokeMethod<bool>('acquireMulticast');
  } catch (_) {
    // Sem o código nativo (versão antiga), segue sem a trava.
  }
}
