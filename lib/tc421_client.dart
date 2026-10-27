import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'tc421_protocol.dart';

/// Conversa com a controladora por UDP.
///
/// Como no programa original, todos os comandos saem em broadcast na porta
/// 5000; o MAC embutido no pacote indica a qual controladora ele se destina.
class Tc421Client {
  RawDatagramSocket? _socket;
  final StreamController<Uint8List> _incoming = StreamController.broadcast();
  String? mac;

  /// IP da controladora. Se for null, os pacotes saem em broadcast.
  /// No iPhone o broadcast exige uma permissão da Apple, então use o IP.
  InternetAddress? target;

  bool get isOpen => _socket != null;

  /// Ponte pela internet: o ESP32 repassa o pacote para a luminária e devolve
  /// a resposta. Usada quando a luminária não responde na rede local.
  Future<Uint8List?> Function(Uint8List packet, int waitMs)? relay;

  /// Está falando com a luminária pela internet?
  bool viaRelay = false;

  /// Define o IP de destino. Texto vazio volta ao broadcast.
  void setTarget(String? ip) {
    final text = ip?.trim() ?? '';
    if (text.isEmpty) {
      target = null;
      return;
    }
    final parsed = InternetAddress.tryParse(text);
    if (parsed == null || parsed.type != InternetAddressType.IPv4) {
      throw FormatException('IP inválido: $text');
    }
    target = parsed;
  }

  Future<void> open() async {
    if (_socket != null) return;
    RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4, Tc421Protocol.port,
          reuseAddress: true);
    } catch (_) {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8000,
          reuseAddress: true);
    }
    socket.broadcastEnabled = true;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? d;
      while ((d = socket.receive()) != null) {
        _incoming.add(d!.data);
      }
    });
    _socket = socket;
  }

  void close() {
    _socket?.close();
    _socket = null;
  }

  void _send(Uint8List packet) {
    final r = relay;
    if (viaRelay && r != null) {
      r(packet, 0);
      return;
    }
    if (_socket == null) return;
    _socket!.send(packet, target ?? InternetAddress('255.255.255.255'),
        Tc421Protocol.port);
  }

  /// Envia [packet] e espera uma resposta aceita por [accept].
  Future<Uint8List?> _request(
    Uint8List packet, {
    bool Function(Uint8List)? accept,
    Duration timeout = const Duration(milliseconds: 600),
  }) async {
    final test = accept ?? Tc421Protocol.isDeviceReply;
    final relayFn = relay;
    if (viaRelay && relayFn != null) {
      final r = await relayFn(packet, timeout.inMilliseconds);
      return (r != null && test(r)) ? r : null;
    }
    final reply = _incoming.stream.where(test).first.timeout(
          timeout,
          onTimeout: () => Uint8List(0),
        );
    _send(packet);
    final r = await reply;
    return r.isEmpty ? null : r;
  }

  String _requireMac() {
    final m = mac;
    if (m == null) throw StateError('Controladora não encontrada.');
    return m;
  }

  /// Procura a controladora na rede. Retorna o MAC ou null.
  Future<String?> discover({int attempts = 3}) async {
    // Primeiro na rede de casa (no navegador isso não existe)...
    viaRelay = false;
    if (!kIsWeb) {
      try {
        await open();
        for (var i = 0; i < attempts; i++) {
          final r = await _request(
            Tc421Protocol.search(),
            accept: (b) => Tc421Protocol.parseSearchReply(b) != null,
          );
          if (r != null) {
            mac = Tc421Protocol.parseSearchReply(r);
            return mac;
          }
        }
      } on SocketException {
        // Sem rede local (ex.: só dados móveis): tenta pela internet.
      }
    }
    // ...depois pela internet, através do ESP32.
    if (relay != null) {
      viaRelay = true;
      for (var i = 0; i < 2; i++) {
        final r = await _request(
          Tc421Protocol.search(),
          accept: (b) => Tc421Protocol.parseSearchReply(b) != null,
          timeout: const Duration(milliseconds: 1500),
        );
        if (r != null) {
          mac = Tc421Protocol.parseSearchReply(r);
          return mac;
        }
      }
      viaRelay = false;
    }
    return null;
  }

  Future<bool> syncTime() async {
    final r = await _request(Tc421Protocol.timeSync(_requireMac(), DateTime.now()));
    return r != null && r[4] == Tc421Protocol.ackTime;
  }

  Future<bool> clearAllModels() async {
    final r = await _request(Tc421Protocol.clearAll(_requireMac()));
    return r != null && r[4] == Tc421Protocol.ackClear;
  }

  // ---- Controle ao vivo (experimental) -----------------------------------

  void beginLive() =>
      _send(Tc421Protocol.readyPlay(_requireMac(), 'Ao vivo'));

  void sendLive(List<int> values) =>
      _send(Tc421Protocol.playValues(_requireMac(), values));

  Future<void> endLive() async {
    await _request(Tc421Protocol.endTransmission(_requireMac()));
  }

  // ---- Cronograma ---------------------------------------------------------

  /// Envia os 48 pontos. Retorna null em caso de sucesso, ou uma mensagem de erro.
  Future<String?> uploadSchedule(
    List<List<int>> schedule,
    String name,
    void Function(double progress) onProgress,
  ) async {
    final m = _requireMac();

    final start = await _request(Tc421Protocol.readyLoad(m, name, 0));
    if (start == null || start[4] != Tc421Protocol.ackLoadName) {
      return 'A controladora não aceitou o início do envio.';
    }

    for (var i = 0; i < Tc421Protocol.pointCount; i++) {
      final block = Tc421Protocol.scheduleBlock(i, schedule[i]);
      var ok = false;
      for (var attempt = 0; attempt < 3 && !ok; attempt++) {
        final r = await _request(Tc421Protocol.loadValue(m, block));
        ok = r != null && r[4] == Tc421Protocol.ackLoadValue;
      }
      if (!ok) {
        await _request(Tc421Protocol.endTransmission(m));
        final h = (i ~/ 2).toString().padLeft(2, '0');
        final min = i.isEven ? '00' : '30';
        return 'Sem resposta ao enviar o ponto das $h:$min.';
      }
      onProgress((i + 1) / Tc421Protocol.pointCount);
    }

    await _request(Tc421Protocol.endTransmission(m));
    return null;
  }
}
