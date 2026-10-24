import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tc421_app/tc421_protocol.dart';

// Vetores gerados por uma porta em Python do código C# de referência
// (ProtocolUsb.cs / ProtocolWifi.cs do repositório sdotter/TC421).
const mac = 'A1B2C3D4E5F6';

String hex(Uint8List p) =>
    p.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('busca', () {
    expect(hex(Tc421Protocol.search()), '55aa17000003ddeeff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e30000');
  });

  test('sincronizar hora', () {
    final t = DateTime(2026, 10, 24, 1, 41, 7);
    expect(hex(Tc421Protocol.timeSync(mac, t)), '55aa0200000707ea0a180129070000000000000000000000000000000000000000000000000000000000000000000000004131423243334434453546364c0000');
  });

  test('apagar modos', () {
    expect(hex(Tc421Protocol.clearAll(mac)), '55aa05fe000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000413142324333443445354636020000');
  });

  test('iniciar controle ao vivo', () {
    expect(hex(Tc421Protocol.readyPlay(mac, 'Ao vivo')), '55aa0601000700416f207669766f0000000000000000000000000000000000000000000000000000000000000000000000413142324333443445354636a10000');
  });

  test('valores ao vivo', () {
    expect(hex(Tc421Protocol.playValues(mac, [100, 50, 0, 0, 25])),
        '55aa0602000564320000190000000000000000000000000000000000000000000000000000000000000000000000000000413142324333443445354636bb0000');
  });

  test('fim da transmissão', () {
    expect(hex(Tc421Protocol.endTransmission(mac)), '55aa03080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004131423243334434453546360a0000');
  });

  test('abrir envio de cronograma', () {
    expect(hex(Tc421Protocol.readyLoad(mac, 'App', 0)), '55aa0101000300417070000000000000000000000000000000000000000000000000000000000000000000000000000000413142324333443445354636250000');
  });

  test('ponto do cronograma', () {
    final block = Tc421Protocol.scheduleBlock(3, [10, 20, 30, 40, 50]);
    expect(block, [3, 1, 30, 10, 20, 30, 40, 50]);
    expect(hex(Tc421Protocol.loadValue(mac, block)), '55aa0102000803011e0a141e28320000000000000000000000000000000000000000000000000000000000000000000000413142324333443445354636c20000');
  });

  test('resposta da busca', () {
    final reply = Uint8List(64)
      ..[0] = 0x88
      ..[2] = 0x17
      ..setRange(4, 16, mac.codeUnits);
    expect(Tc421Protocol.parseSearchReply(reply), mac);
    expect(Tc421Protocol.parseSearchReply(Uint8List(64)), isNull);
  });

  test('valores fora de 0..100 são limitados', () {
    final p = Tc421Protocol.playValues(mac, [-5, 250, 0, 0, 0]);
    expect(p[6], 0);
    expect(p[7], 100);
  });
}
