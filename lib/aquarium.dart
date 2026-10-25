import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modos de cada tomada (iguais aos do programa do ESP32).
class OutletMode {
  static const off = 0, on = 1, schedule = 2, auto = 3, dose = 4;
}

class OutletState {
  OutletState(Map<String, dynamic> j)
      : id = j['id'] as int,
        name = j['name'] as String,
        on = j['on'] as bool,
        mode = j['mode'] as int,
        onMin = j['onMin'] as int,
        offMin = j['offMin'] as int,
        doseSec = j['doseSec'] as int;

  final int id;
  final String name;
  final bool on;
  final int mode;
  final int onMin;
  final int offMin;
  final int doseSec;

  /// Quais modos fazem sentido para cada tomada (índices do ESP32).
  List<int> get modes {
    switch (id) {
      case 2: // reposição
      case 4: // aquecedor
      case 5: // resfriamento
        return [OutletMode.off, OutletMode.on, OutletMode.auto];
      case 8: // dosadora
        return [OutletMode.off, OutletMode.dose, OutletMode.on];
      default:
        return [OutletMode.off, OutletMode.on, OutletMode.schedule];
    }
  }
}

String modeName(int mode) => switch (mode) {
      OutletMode.off => 'Desligado',
      OutletMode.on => 'Ligado',
      OutletMode.schedule => 'Horário',
      OutletMode.auto => 'Automático',
      OutletMode.dose => 'Dose diária',
      _ => '?',
    };

String minuteLabel(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

/// Fala com o ESP32 do aquário pela rede local (HTTP).
class AquariumController extends ChangeNotifier {
  String ip = '';
  bool connected = false;
  bool busy = false;
  String status = 'Informe o IP da controladora do aquário.';
  Timer? _timer;

  double? temp, ph, ec, salinity;
  bool adsOk = false;
  bool timeOk = false;
  bool phCal = false;
  bool ecCal = false;
  List<String> alarms = [];
  List<OutletState> outlets = [];
  bool atoSumpLow = false, atoReservoirEmpty = false, atoFault = false;
  Map<String, double> thermo = {};

  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    ip = prefs.getString('aquarium_ip') ?? '';
    _timer?.cancel();
    if (ip.isEmpty) {
      notifyListeners();
      return;
    }
    await refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }

  Future<void> setIp(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final text = value.trim();
    if (text.isEmpty) {
      await prefs.remove('aquarium_ip');
    } else {
      await prefs.setString('aquarium_ip', text);
    }
    connected = false;
    status = text.isEmpty
        ? 'Informe o IP da controladora do aquário.'
        : 'Conectando em $text...';
    await start();
  }

  Future<Map<String, dynamic>?> _get(String path,
      [Map<String, String>? query]) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client.getUrl(Uri.http(ip, path, query));
      final res = await req.close().timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> refresh() async {
    if (ip.isEmpty || busy) return;
    final j = await _get('/api/status');
    _apply(j);
  }

  void _apply(Map<String, dynamic>? j) {
    if (j == null) {
      connected = false;
      status = 'Sem resposta de $ip. Confira se o ESP32 está ligado e na mesma rede.';
      notifyListeners();
      return;
    }
    try {
      double? d(dynamic v) => v == null ? null : (v as num).toDouble();
      temp = d(j['temp']);
      ph = d(j['ph']);
      ec = d(j['ec']);
      salinity = d(j['salinity']);
      adsOk = j['adsOk'] as bool;
      timeOk = j['timeOk'] as bool;
      alarms = [for (final a in j['alarms'] as List) a as String];
      outlets = [
        for (final o in j['outlets'] as List)
          OutletState(o as Map<String, dynamic>)
      ];
      final ato = j['ato'] as Map<String, dynamic>;
      atoSumpLow = ato['sumpLow'] as bool;
      atoReservoirEmpty = ato['reservoirEmpty'] as bool;
      atoFault = ato['fault'] as bool;
      thermo = {
        for (final e in (j['thermo'] as Map<String, dynamic>).entries)
          e.key: (e.value as num).toDouble()
      };
      final cal = j['cal'] as Map<String, dynamic>;
      phCal = cal['ph'] as bool;
      ecCal = cal['ec'] as bool;
      connected = true;
      status = 'Conectada em $ip';
    } catch (_) {
      connected = false;
      status = 'Resposta inesperada de $ip. O programa do ESP32 é o mesmo da pasta firmware?';
    }
    notifyListeners();
  }

  Future<void> _send(String path, Map<String, String> query) async {
    busy = true;
    _apply(await _get(path, query));
    busy = false;
  }

  Future<void> setOutlet(int id, int mode,
      {int? onMin, int? offMin, int? doseSec}) {
    return _send('/api/set', {
      'id': '$id',
      'mode': '$mode',
      if (onMin != null) 'on': '$onMin',
      if (offMin != null) 'off': '$offMin',
      if (doseSec != null) 'sec': '$doseSec',
    });
  }

  Future<void> setThermo(Map<String, double> values) =>
      _send('/api/thermo', {for (final e in values.entries) e.key: '${e.value}'});

  Future<void> calibratePh(int point) =>
      _send('/api/cal', {'type': 'ph', 'point': '$point'});

  Future<void> calibrateEc(double reference) =>
      _send('/api/cal', {'type': 'ec', 'ref': '$reference'});

  Future<void> resetAto() => _send('/api/atoreset', {});

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
