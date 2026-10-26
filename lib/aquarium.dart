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
      case 7: // TPA: retirar
      case 8: // TPA: repor
        return [OutletMode.auto]; // só a rotina da TPA liga estas bombas
      default:
        return [OutletMode.off, OutletMode.on, OutletMode.schedule];
    }
  }
}

/// Um canal da dosadora (bomba peristáltica).
class DoserChannel {
  DoserChannel(Map<String, dynamic> j)
      : name = j['name'] as String,
        enabled = j['en'] as bool,
        mlDay = (j['mlDay'] as num).toDouble(),
        doses = j['doses'] as int,
        start = j['start'] as int,
        end = j['end'] as int,
        rate = (j['rate'] as num).toDouble(),
        capacity = (j['cap'] as num).toDouble(),
        left = (j['left'] as num).toDouble(),
        today = (j['today'] as num).toDouble(),
        pending = (j['pending'] as num).toDouble(),
        next = j['next'] as int,
        empty = j['empty'] as bool;

  final String name;
  final bool enabled;
  final double mlDay;
  final int doses;
  final int start;
  final int end;

  /// ml por minuto (calibração).
  final double rate;
  final double capacity;
  final double left;
  final double today;
  final double pending;

  /// Minuto do dia da próxima dose (-1 = nenhuma hoje).
  final int next;
  final bool empty;

  double get perDose => doses == 0 ? 0 : mlDay / doses;

  /// Quantos dias o recipiente ainda dura.
  int? get daysLeft => mlDay <= 0 ? null : (left / mlDay).floor();
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

  // TPA: 0 parada, 1 retirando, 2 pausa, 3 repondo
  int tpaState = 0;
  int tpaElapsed = 0;
  int tpaTotal = 0;
  double tpaLiters = 10, tpaDrainLpm = 5, tpaFillLpm = 5;
  bool tpaMinLevel = false;
  String tpaMsg = '';

  // Dosadora (4 canais)
  List<DoserChannel> doser = [];
  int doserRunning = -1;
  bool doserCalib = false;
  int doserElapsed = 0, doserTotal = 0;
  String doserMsg = '';

  /// O programa do ESP32 já tem a dosadora de 4 canais?
  bool get hasDoser => doser.isNotEmpty;

  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    ip = prefs.getString('aquarium_ip') ?? '';
    _timer?.cancel();
    if (ip.isEmpty) {
      notifyListeners();
      return;
    }
    await refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
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

  /// Última resposta recebida; se a nova for igual, as telas não redesenham.
  String? _lastSignature;

  void _apply(Map<String, dynamic>? j) {
    final signature = j == null ? 'offline' : jsonEncode(j);
    if (signature == _lastSignature) return;
    _lastSignature = signature;
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
      final tpa = j['tpa'] as Map<String, dynamic>;
      tpaState = tpa['state'] as int;
      tpaElapsed = (tpa['elapsed'] as num).toInt();
      tpaTotal = (tpa['total'] as num).toInt();
      tpaLiters = (tpa['liters'] as num).toDouble();
      tpaDrainLpm = (tpa['drainLpm'] as num).toDouble();
      tpaFillLpm = (tpa['fillLpm'] as num).toDouble();
      tpaMinLevel = tpa['minLevel'] as bool;
      tpaMsg = tpa['msg'] as String;
      final cal = j['cal'] as Map<String, dynamic>;
      phCal = cal['ph'] as bool;
      ecCal = cal['ec'] as bool;
      final ds = j['doser'];
      if (ds is Map<String, dynamic>) {
        doserRunning = ds['running'] as int;
        doserCalib = ds['calib'] as bool;
        doserElapsed = (ds['elapsed'] as num).toInt();
        doserTotal = (ds['total'] as num).toInt();
        doserMsg = ds['msg'] as String;
        doser = [
          for (final c in ds['ch'] as List)
            DoserChannel(c as Map<String, dynamic>)
        ];
      } else {
        doser = [];
      }
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

  Future<void> tpaStart() => _send('/api/tpa/start', {});

  Future<void> tpaStop() => _send('/api/tpa/stop', {});

  Future<void> setTpaConfig(double liters, double drainLpm, double fillLpm) =>
      _send('/api/tpa/config', {
        'liters': '$liters',
        'drainLpm': '$drainLpm',
        'fillLpm': '$fillLpm',
      });

  // ---- Dosadora ----

  Future<void> setDoser(
    int ch, {
    String? name,
    bool? enabled,
    double? mlDay,
    int? doses,
    int? start,
    int? end,
    double? rate,
    double? capacity,
  }) =>
      _send('/api/doser/set', {
        'ch': '$ch',
        if (name != null) 'name': name,
        if (enabled != null) 'en': enabled ? '1' : '0',
        if (mlDay != null) 'ml': mlDay.toStringAsFixed(1),
        if (doses != null) 'n': '$doses',
        if (start != null) 'start': '$start',
        if (end != null) 'end': '$end',
        if (rate != null) 'rate': rate.toStringAsFixed(1),
        if (capacity != null) 'cap': capacity.toStringAsFixed(0),
      });

  Future<void> refillDoser(int ch) => _send('/api/doser/refill', {'ch': '$ch'});

  Future<void> doseNow(int ch, double ml) =>
      _send('/api/doser/dose', {'ch': '$ch', 'ml': ml.toStringAsFixed(1)});

  /// Liga a bomba por 1 minuto para medir a vazão.
  Future<void> calibrateDoser(int ch) => _send('/api/doser/calib', {'ch': '$ch'});

  Future<void> stopDoser() => _send('/api/doser/stop', {});

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
