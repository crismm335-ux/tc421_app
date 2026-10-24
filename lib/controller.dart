import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Cronograma: 48 pontos x 5 canais
  final List<List<int>> schedule = List.generate(
    Tc421Protocol.pointCount,
    (_) => List.filled(Tc421Protocol.channelCount, 0),
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
      _client.endLive();
    }
    notifyListeners();
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

  void setPoint(int index, int channel, int value) {
    schedule[index][channel] = value;
    notifyListeners();
  }

  void copyPointToAll(int index) {
    final src = List<int>.from(schedule[index]);
    for (final row in schedule) {
      row.setAll(0, src);
    }
    notifyListeners();
  }

  void applyPreset(SchedulePreset preset) {
    for (var i = 0; i < schedule.length; i++) {
      final minutes = i * 30;
      final level = switch (preset) {
        SchedulePreset.allOn => 100,
        SchedulePreset.allOff => 0,
        SchedulePreset.daylight => _daylight(minutes),
      };
      schedule[i].fillRange(0, schedule[i].length, level);
    }
    notifyListeners();
  }

  /// Sobe de 07:00 a 09:00, fica em 100% até 19:00 e desce até 21:00.
  int _daylight(int m) {
    if (m < 420 || m >= 1260) return 0;
    if (m < 540) return ((m - 420) * 100 / 120).round();
    if (m < 1140) return 100;
    return ((1260 - m) * 100 / 120).round();
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
    _client.close();
    super.dispose();
  }
}
