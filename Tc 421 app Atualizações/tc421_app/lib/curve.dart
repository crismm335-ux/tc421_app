/// Curva de intensidade de um canal ao longo do dia.
///
/// Os pontos ficam entre 00:00 (minuto 0) e 24:00 (minuto 1440). A controladora
/// guarda um valor a cada 30 minutos, então os horários andam de 30 em 30.

const int dayMinutes = 1440;
const int minuteStep = 30;

int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

/// Arredonda para o múltiplo de 30 minutos mais próximo, entre 0 e 1440.
int snapMinute(num minute) {
  final snapped = (minute / minuteStep).round() * minuteStep;
  return _clampInt(snapped, 0, dayMinutes);
}

/// "08:30"; o minuto 1440 vira "24:00".
String timeLabel(int minute) {
  final h = (minute ~/ 60).toString().padLeft(2, '0');
  final m = (minute % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

class CurvePoint {
  CurvePoint(this.minute, this.value);

  int minute; // 0..1440
  int value; // 0..100
}

class DayCurve {
  DayCurve(Iterable<CurvePoint> pts)
      : points = (pts.toList()..sort((a, b) => a.minute.compareTo(b.minute)));

  final List<CurvePoint> points;

  /// Mesma intensidade o dia todo.
  factory DayCurve.flat(int value) =>
      DayCurve([CurvePoint(0, value), CurvePoint(dayMinutes, value)]);

  /// Sobe de 07:00 a 09:00, fica em 100% até 19:00 e desce até 21:00.
  factory DayCurve.daylight() => DayCurve([
        CurvePoint(0, 0),
        CurvePoint(420, 0),
        CurvePoint(540, 100),
        CurvePoint(1140, 100),
        CurvePoint(1260, 0),
        CurvePoint(dayMinutes, 0),
      ]);

  DayCurve copy() => DayCurve(points.map((p) => CurvePoint(p.minute, p.value)));

  /// Intensidade (0..100) em [minute], com subida e descida em linha reta
  /// entre os pontos.
  int valueAt(int minute) {
    if (minute <= points.first.minute) return points.first.value;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (minute <= b.minute) {
        final span = b.minute - a.minute;
        if (span == 0) return b.value;
        return (a.value + (b.value - a.value) * (minute - a.minute) / span)
            .round();
      }
    }
    return points.last.value;
  }

  /// Cria um ponto. Retorna o índice dele, ou -1 se já existe um ponto
  /// nesse horário.
  int addPoint(int minute, int value) {
    final m = snapMinute(minute);
    if (points.any((p) => p.minute == m)) return -1;
    final point = CurvePoint(m, _clampInt(value, 0, 100));
    var i = points.indexWhere((q) => q.minute > m);
    if (i == -1) i = points.length;
    points.insert(i, point);
    return i;
  }

  /// Apaga um ponto. O primeiro (00:00) e o último (24:00) não saem.
  void removeAt(int index) {
    if (index <= 0 || index >= points.length - 1) return;
    points.removeAt(index);
  }

  /// Move um ponto sem passar por cima dos vizinhos. Os pontos das pontas
  /// só mudam de intensidade.
  void move(int index, int minute, int value) {
    final p = points[index];
    p.value = _clampInt(value, 0, 100);
    if (index == 0 || index == points.length - 1) return;
    final lo = points[index - 1].minute + minuteStep;
    final hi = points[index + 1].minute - minuteStep;
    if (lo <= hi) p.minute = _clampInt(snapMinute(minute), lo, hi);
  }
}
