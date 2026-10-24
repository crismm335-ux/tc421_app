import 'dart:convert';
import 'dart:typed_data';

/// Pacotes UDP da TC421 (64 bytes cada).
///
/// Baseado na engenharia reversa publicada em github.com/sdotter/TC421.
/// Todo pacote (exceto a busca) é montado no formato "USB" e depois convertido
/// para WiFi: o checksum sai do byte 63 e vai para o 61, e o MAC do dispositivo
/// (12 caracteres ASCII) é copiado para os bytes 49..60.
class Tc421Protocol {
  Tc421Protocol._();

  static const int size = 64;
  static const int port = 5000;
  static const int channelCount = 5;
  static const int pointCount = 48; // um ponto a cada 30 minutos

  /// Códigos de confirmação (byte 4 da resposta da controladora).
  static const int ackLoadName = 0x80;
  static const int ackLoadValue = 0x81;
  static const int ackClear = 0x82;
  static const int ackTime = 0x85;

  static Uint8List _packet(int cmd, int sub) {
    final p = Uint8List(size);
    p[0] = 0x55;
    p[1] = 0xAA;
    p[2] = cmd;
    p[3] = sub;
    return p;
  }

  /// Soma dos primeiros [count] bytes, gravada no último byte.
  static void _sum(Uint8List p, int count) {
    var s = 0;
    for (var i = 0; i < count; i++) {
      s += p[i];
    }
    p[size - 1] = s & 0xFF;
  }

  static Uint8List _toWifi(Uint8List p, String mac) {
    if (mac.length != 12) {
      throw ArgumentError('MAC deve ter 12 caracteres, recebeu "$mac"');
    }
    p[size - 3] = p[size - 1];
    p[size - 1] = 0;
    p.setRange(size - 15, size - 3, ascii.encode(mac));
    return p;
  }

  /// Nomes têm no máximo 8 caracteres ASCII.
  static Uint8List _nameBytes(String name) {
    final clean = name.replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
    final cut = clean.length > 8 ? clean.substring(0, 8) : clean;
    return Uint8List.fromList(ascii.encode(cut));
  }

  static int _clamp(int v) => v < 0 ? 0 : (v > 100 ? 100 : v);

  /// Broadcast para descobrir a controladora e seu MAC.
  static Uint8List search() {
    final p = Uint8List(size);
    p[0] = 0x55;
    p[1] = 0xAA;
    p[2] = 0x17;
    p[5] = 3;
    p[6] = 0xDD;
    p[7] = 0xEE;
    p[8] = 0xFF;
    p[61] = 0xE3;
    return p;
  }

  /// Retorna o MAC contido na resposta da busca, ou null se não for uma.
  static String? parseSearchReply(Uint8List b) {
    if (b.length < 16 || b[0] != 0x88 || b[1] != 0 || b[2] != 0x17) {
      return null;
    }
    return ascii.decode(b.sublist(4, 16), allowInvalid: true);
  }

  /// Resposta válida de uma controladora (filtra o eco dos nossos pacotes).
  static bool isDeviceReply(Uint8List b) =>
      b.length > 4 && b[0] == 0x88 && b[1] == 0;

  static Uint8List timeSync(String mac, DateTime t) {
    final p = _packet(2, 0);
    p[5] = 7;
    p[6] = (t.year >> 8) & 0xFF;
    p[7] = t.year & 0xFF;
    p[8] = t.month;
    p[9] = t.day;
    p[10] = t.hour;
    p[11] = t.minute;
    p[12] = t.second;
    _sum(p, 13);
    return _toWifi(p, mac);
  }

  static Uint8List clearAll(String mac) {
    final p = _packet(5, 0xFE);
    p[size - 1] = 2;
    return _toWifi(p, mac);
  }

  /// Inicia o modo "play" (controle ao vivo) com um nome de até 8 caracteres.
  static Uint8List readyPlay(String mac, String name) {
    final n = _nameBytes(name);
    final p = _packet(6, 1);
    p[5] = n.length;
    p.setRange(7, 7 + n.length, n);
    _sum(p, 7 + n.length);
    return _toWifi(p, mac);
  }

  /// Valores ao vivo dos canais (0 a 100).
  static Uint8List playValues(String mac, List<int> values) {
    final v = values.map(_clamp).toList();
    final p = _packet(6, 2);
    p[5] = v.length;
    p.setRange(6, 6 + v.length, v);
    _sum(p, 6 + v.length);
    return _toWifi(p, mac);
  }

  static Uint8List endTransmission(String mac) {
    final p = _packet(3, 8);
    p[size - 1] = 10;
    return _toWifi(p, mac);
  }

  /// Abre o envio de um cronograma.
  static Uint8List readyLoad(String mac, String name, int index) {
    final n = _nameBytes(name);
    final p = _packet(1, 1);
    p[5] = n.length;
    p[6] = index;
    p.setRange(7, 7 + n.length, n);
    _sum(p, 7 + n.length);
    return _toWifi(p, mac);
  }

  /// Um ponto do cronograma: [índice, hora, minuto, canal1..canal5].
  static Uint8List scheduleBlock(int index, List<int> channels) {
    return Uint8List.fromList([
      index,
      index ~/ 2,
      index.isEven ? 0 : 30,
      ...channels.map(_clamp),
    ]);
  }

  static Uint8List loadValue(String mac, Uint8List block) {
    final p = _packet(1, 2);
    p[5] = 8;
    p.setRange(6, 6 + block.length, block);
    _sum(p, 6 + block.length);
    return _toWifi(p, mac);
  }
}
