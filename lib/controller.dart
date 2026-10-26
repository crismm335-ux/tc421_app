import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curve.dart';
import 'tc421_client.dart';
import 'tc421_protocol.dart';

enum SchedulePreset { allOn, allOff, daylight }

/// Estado do app: conexão, controle ao vivo e cronograma.
class Tc421Controller extends ChangeNotifier {
  final Tc421Client _client = Tc421Client();

  String status = 'Procurando a controladora...';
  bool searching = false;
  bool get connected => _client.mac != null;
  String? get mac => _client.mac;

  // Controle ao vivo
  final List<int> live = List.filled(Tc421Protocol.channelCount, 0);
  bool liveActive = false;
  Timer? _liveTimer;
  bool _liveDirty = false;

  // Simulação do dia inteiro na luminária (acelerada).
  bool simulating = false;
  int simSeconds = 30; // quanto tempo o dia de 24 h leva na simulação
  int simMinute = 0; // horário simulado agora (0..1440)
  Timer? _simTimer;
  final Stopwatch _simClock = Stopwatch();

  // Cronograma: uma curva por canal (pontos arrastáveis no gráfico).
  final List<DayCurve> curves = profileCurves('Recife Natural')!;
  int selectedChannel = 0;
  int selectedPoint = 0;
  String profileName = 'Recife Natural';

  /// Os 48 valores (um a cada 30 min) x 5 canais que a controladora recebe.
  List<List<int>> get schedule => List.generate(
        Tc421Protocol.pointCount,
        (i) => List.generate(
          Tc421Protocol.channelCount,
          (c) => curves[c].valueAt(i * minuteStep),
        ),
      );
  double? uploadProgress;
  String? uploadMessage;

  /// IP informado pelo usuário (null = busca por broadcast).
  String? manualIp;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    manualIp = prefs.getString('controller_ip');
  }

  Future<void> setManualIp(String? ip) async {
    final text = ip?.trim() ?? '';
    final prefs = await SharedPreferences.getInstance();
    if (text.isEmpty) {
      await prefs.remove('controller_ip');
      manualIp = null;
    } else {
      await prefs.setString('controller_ip', text);
      manualIp = text;
    }
    await connect();
  }

  Future<void> connect() async {
    if (searching) return;
    searching = true;
    status = manualIp == null
        ? 'Procurando a controladora...'
        : 'Conectando em $manualIp...';
    notifyListeners();
    try {
      _client.setTarget(manualIp);
      final mac = await _client.discover();
      if (mac != null) {
        status = 'Conectado: $mac';
      } else if (manualIp != null) {
        status = 'Sem resposta de $manualIp. Confira o IP e se o celular está no mesmo WiFi.';
      } else if (Platform.isIOS) {
        status = 'Não achei por broadcast (o iPhone limita isso). Toque no ícone de rede e informe o IP da controladora.';
      } else {
        status = 'Não encontrei a controladora. Confira se o celular está no mesmo WiFi dela.';
      }
    } on FormatException catch (e) {
      status = e.message;
    } catch (e) {
      status = 'Erro de rede: $e';
    }
    searching = false;
    notifyListeners();
  }

  Future<void> syncTime() async {
    if (!connected) return;
    final ok = await _client.syncTime();
    status = ok
        ? 'Hora sincronizada com o celular.'
        : 'A controladora não confirmou a sincronização.';
    notifyListeners();
  }

  // ---- Ao vivo ------------------------------------------------------------

  void setLiveActive(bool on) {
    if (!connected) return;
    liveActive = on;
    if (on) {
      _client.beginLive();
      _client.sendLive(live);
    } else {
      liveMode = null;
      _client.endLive();
    }
    notifyListeners();
  }

  /// Modo rápido da tela inicial ("Recife", "Noturno"...); null = cronograma.
  String? liveMode;

  /// Média dos canais agora, segundo o cronograma (ou o ao vivo, se ativo).
  int get currentIntensity {
    if (liveActive) {
      return (live.reduce((a, b) => a + b) / live.length).round();
    }
    final now = DateTime.now();
    final minute = now.hour * 60 + now.minute;
    var sum = 0;
    for (final c in curves) {
      sum += c.valueAt(minute);
    }
    return (sum / curves.length).round();
  }

  /// Liga o controle ao vivo com estes níveis.
  void applyLiveLevels(List<int> levels, String mode) {
    if (!connected) return;
    for (var i = 0; i < live.length && i < levels.length; i++) {
      live[i] = levels[i];
    }
    liveMode = mode;
    if (!liveActive) {
      liveActive = true;
      _client.beginLive();
    }
    _client.sendLive(live);
    notifyListeners();
  }

  /// Volta ao cronograma salvo na controladora.
  void backToSchedule() {
    liveMode = null;
    setLiveActive(false);
  }

  void setLive(int channel, int value) {
    live[channel] = value;
    notifyListeners();
    if (liveActive) _scheduleLiveSend();
  }

  void setAllLive(int value) {
    for (var i = 0; i < live.length; i++) {
      live[i] = value;
    }
    notifyListeners();
    if (liveActive) _scheduleLiveSend();
  }

  /// No máximo ~12 envios por segundo enquanto o slider se mexe.
  void _scheduleLiveSend() {
    if (_liveTimer?.isActive ?? false) {
      _liveDirty = true;
      return;
    }
    _client.sendLive(live);
    _liveTimer = Timer(const Duration(milliseconds: 80), () {
      if (_liveDirty) {
        _liveDirty = false;
        _client.sendLive(live);
      }
    });
  }

  // ---- Cronograma ---------------------------------------------------------

  void setSimSeconds(int seconds) {
    simSeconds = seconds;
    notifyListeners();
  }

  /// Faz a luminária percorrer as 24 h do cronograma em [simSeconds] segundos.
  /// Usa o modo ao vivo (experimental); ao terminar ou parar, a controladora
  /// volta ao cronograma que está salvo nela.
  Future<void> startSimulation() async {
    if (!connected || simulating) return;
    liveActive = false;
    simulating = true;
    simMinute = 0;
    notifyListeners();

    _client.beginLive();
    // A controladora precisa de um instante para entrar no modo ao vivo.
    await Future.delayed(const Duration(milliseconds: 150));
    if (!simulating) return; // foi parada nesse meio tempo

    _simClock
      ..reset()
      ..start();
    _simTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _simTick(),
    );
  }

  void _simTick() {
    final total = simSeconds * 1000;
    final elapsed = _simClock.elapsedMilliseconds;
    if (elapsed >= total) {
      stopSimulation();
      return;
    }
    simMinute = elapsed * dayMinutes ~/ total;
    _client.sendLive(List.generate(
      Tc421Protocol.channelCount,
      (c) => curves[c].valueAt(simMinute),
    ));
    notifyListeners();
  }

  void stopSimulation() {
    if (!simulating) return;
    _simTimer?.cancel();
    _simTimer = null;
    _simClock.stop();
    simulating = false;
    _client.endLive();
    notifyListeners();
  }

  void selectChannel(int channel) {
    selectedChannel = channel;
    _clampPoint();
    notifyListeners();
  }

  DayCurve get currentCurve => curves[selectedChannel];

  void _clampPoint() {
    final last = currentCurve.points.length - 1;
    if (selectedPoint > last) selectedPoint = last;
    if (selectedPoint < 0) selectedPoint = 0;
  }

  void selectPoint(int index) {
    selectedPoint = index;
    _clampPoint();
    notifyListeners();
  }

  /// Chamado pelo gráfico quando um ponto muda.
  void curvesChanged() {
    _clampPoint();
    notifyListeners();
  }

  int get pointCount => currentCurve.points.length;

  /// Intensidade média (0..100) do canal escolhido ao longo do dia.
  int get averageIntensity {
    var sum = 0;
    for (var m = 0; m < dayMinutes; m += minuteStep) {
      sum += currentCurve.valueAt(m);
    }
    return (sum / (dayMinutes / minuteStep)).round();
  }

  void setSelectedPointMinute(int minute) {
    final p = currentCurve.points[selectedPoint];
    currentCurve.move(selectedPoint, minute, p.value);
    notifyListeners();
  }

  void setSelectedPointValue(int value) {
    final p = currentCurve.points[selectedPoint];
    currentCurve.move(selectedPoint, p.minute, value);
    notifyListeners();
  }

  /// Cria um ponto ao lado do selecionado (30 min depois, ou antes se não couber).
  bool addPointNearSelected() {
    final p = currentCurve.points[selectedPoint];
    var i = -1;
    if (p.minute + minuteStep <= dayMinutes) {
      i = currentCurve.addPoint(p.minute + minuteStep, p.value);
    }
    if (i < 0 && p.minute - minuteStep >= 0) {
      i = currentCurve.addPoint(p.minute - minuteStep, p.value);
    }
    if (i < 0) return false;
    selectedPoint = i;
    notifyListeners();
    return true;
  }

  /// Só os pontos do meio podem sair; 00:00 e 24:00 ficam.
  bool get canRemoveSelected =>
      selectedPoint > 0 && selectedPoint < pointCount - 1;

  void removeSelectedPoint() {
    if (!canRemoveSelected) return;
    currentCurve.removeAt(selectedPoint);
    selectedPoint -= 1;
    _clampPoint();
    notifyListeners();
  }

  /// Aplica um perfil pronto (curvas dos 5 canais).
  void applyProfile(String name) {
    final made = profileCurves(name);
    if (made == null) return;
    for (var c = 0; c < curves.length; c++) {
      curves[c] = made[c];
    }
    profileName = name;
    selectedPoint = 0;
    notifyListeners();
  }

  /// JSON no mesmo formato do protótipo Aqua Light: horários em horas.
  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'app': 'Aqua Light TC421',
        'version': 1,
        'profile': profileName,
        'data': [
          for (final c in curves)
            [
              for (final p in c.points) {'t': p.minute / 60, 'v': p.value}
            ]
        ],
      });

  /// Devolve null se deu certo, ou a mensagem de erro.
  String? importJson(String text) {
    try {
      final j = jsonDecode(text);
      final data = j is Map ? j['data'] : null;
      if (data is! List || data.length != Tc421Protocol.channelCount) {
        return 'JSON inválido: precisa ter 5 canais.';
      }
      final made = <DayCurve>[];
      for (final ch in data) {
        final pts = <CurvePoint>[];
        for (final p in (ch as List)) {
          final minute = snapMinute((p['t'] as num) * 60);
          final value = ((p['v'] as num).round()).clamp(0, 100).toInt();
          if (pts.any((q) => q.minute == minute)) continue;
          pts.add(CurvePoint(minute, value));
        }
        if (pts.length < 2) return 'JSON inválido: poucos pontos num canal.';
        pts.sort((a, b) => a.minute.compareTo(b.minute));
        if (pts.first.minute > 0) pts.insert(0, CurvePoint(0, pts.first.value));
        if (pts.last.minute < dayMinutes) {
          pts.add(CurvePoint(dayMinutes, pts.last.value));
        }
        made.add(DayCurve(pts));
      }
      for (var c = 0; c < curves.length; c++) {
        curves[c] = made[c];
      }
      final name = j['profile'];
      profileName = name is String && name.isNotEmpty ? name : 'Importado';
      selectedPoint = 0;
      notifyListeners();
      return null;
    } catch (_) {
      return 'JSON inválido.';
    }
  }

  /// Copia a curva do canal escolhido para todos os outros.
  void copyCurveToAll() {
    final src = curves[selectedChannel];
    for (var c = 0; c < curves.length; c++) {
      if (c != selectedChannel) curves[c] = src.copy();
    }
    _clampPoint();
    notifyListeners();
  }

  void applyPreset(SchedulePreset preset) {
    profileName = 'Personalizado';
    for (var c = 0; c < curves.length; c++) {
      curves[c] = switch (preset) {
        SchedulePreset.allOn => DayCurve.flat(100),
        SchedulePreset.allOff => DayCurve.flat(0),
        SchedulePreset.daylight => DayCurve.daylight(),
      };
    }
    _clampPoint();
    notifyListeners();
  }

  Future<void> uploadSchedule() async {
    if (!connected || uploadProgress != null) return;
    uploadProgress = 0;
    uploadMessage = null;
    notifyListeners();
    try {
      final error = await _client.uploadSchedule(schedule, 'App', (p) {
        uploadProgress = p;
        notifyListeners();
      });
      uploadMessage = error ?? 'Cronograma enviado para a controladora.';
    } catch (e) {
      uploadMessage = 'Erro de rede: $e';
    }
    uploadProgress = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _simTimer?.cancel();
    _client.close();
    super.dispose();
  }
}
