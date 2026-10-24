import 'package:flutter/material.dart';

import 'curve.dart';

/// Converte entre pixels e (horário, intensidade).
class ChartGeometry {
  ChartGeometry(this.size);

  final Size size;

  static const double left = 42;
  static const double right = 16;
  static const double top = 24;
  static const double bottom = 30;

  Rect get plot => Rect.fromLTRB(
      left, top, size.width - right, size.height - bottom);

  Offset toPixel(int minute, int value) => Offset(
        plot.left + minute / dayMinutes * plot.width,
        plot.bottom - value / 100 * plot.height,
      );

  int minuteAt(double dx) =>
      ((dx - plot.left) / plot.width * dayMinutes).round();

  int valueAt(double dy) =>
      ((plot.bottom - dy) / plot.height * 100).round();
}

/// Gráfico do dia: arraste um ponto para os lados (horário) e para cima ou
/// para baixo (intensidade). Toque num espaço vazio para criar um ponto e
/// segure um ponto para apagar.
class CurveEditor extends StatefulWidget {
  const CurveEditor({
    super.key,
    required this.curves,
    required this.colors,
    required this.selected,
    required this.onChanged,
    this.playhead,
    this.enabled = true,
  });

  final List<DayCurve> curves;
  final List<Color> colors;
  final int selected;
  final VoidCallback onChanged;

  /// Horário (minutos) da linha que anda durante a simulação; null = sem linha.
  final int? playhead;

  /// false trava a edição (durante a simulação).
  final bool enabled;

  @override
  State<CurveEditor> createState() => _CurveEditorState();
}

class _CurveEditorState extends State<CurveEditor> {
  int? _drag;

  DayCurve get _curve => widget.curves[widget.selected];

  /// Ponto do canal escolhido mais perto do dedo (até 36 px), ou null.
  int? _hit(Offset p, Size size) {
    final g = ChartGeometry(size);
    int? best;
    var bestDistance = 36.0;
    for (var i = 0; i < _curve.points.length; i++) {
      final pt = _curve.points[i];
      final d = (g.toPixel(pt.minute, pt.value) - p).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final g = ChartGeometry(size);
        return IgnorePointer(
          ignoring: !widget.enabled,
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            setState(() => _drag = _hit(d.localPosition, size));
          },
          onPanUpdate: (d) {
            final i = _drag;
            if (i == null) return;
            _curve.move(
              i,
              g.minuteAt(d.localPosition.dx),
              g.valueAt(d.localPosition.dy),
            );
            widget.onChanged();
          },
          onPanEnd: (_) => setState(() => _drag = null),
          onPanCancel: () => setState(() => _drag = null),
          onTapUp: (d) {
            final p = d.localPosition;
            if (_hit(p, size) != null || !g.plot.inflate(8).contains(p)) {
              return;
            }
            final i = _curve.addPoint(g.minuteAt(p.dx), g.valueAt(p.dy));
            if (i >= 0) widget.onChanged();
          },
          onLongPressStart: (d) {
            final i = _hit(d.localPosition, size);
            if (i == null) return;
            _curve.removeAt(i);
            widget.onChanged();
          },
          child: CustomPaint(
            size: size,
            painter: _CurvePainter(
              curves: widget.curves,
              colors: widget.colors,
              selected: widget.selected,
              dragIndex: _drag,
              gridColor: scheme.outlineVariant,
              textColor: scheme.onSurfaceVariant,
              tooltipColor: scheme.inverseSurface,
              tooltipTextColor: scheme.onInverseSurface,
              playhead: widget.playhead,
            ),
          ),
          ),
        );
      },
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.curves,
    required this.colors,
    required this.selected,
    required this.dragIndex,
    required this.gridColor,
    required this.textColor,
    required this.tooltipColor,
    required this.tooltipTextColor,
    this.playhead,
  });

  final List<DayCurve> curves;
  final List<Color> colors;
  final int selected;
  final int? dragIndex;
  final Color gridColor;
  final Color textColor;
  final Color tooltipColor;
  final Color tooltipTextColor;
  final int? playhead;

  TextPainter _label(String text, double fontSize, Color color) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: color, fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  Path _linePath(ChartGeometry g, DayCurve curve) {
    final path = Path();
    for (var i = 0; i < curve.points.length; i++) {
      final o = g.toPixel(curve.points[i].minute, curve.points[i].value);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = ChartGeometry(size);
    final plot = g.plot;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (final v in const [0, 25, 50, 75, 100]) {
      final y = g.toPixel(0, v).dy;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final t = _label('$v%', 11, textColor);
      t.paint(canvas, Offset(plot.left - t.width - 6, y - t.height / 2));
    }
    for (var h = 0; h <= 24; h += 3) {
      final x = g.toPixel(h * 60, 0).dx;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      if (h % 6 == 0) {
        final t = _label('${h.toString().padLeft(2, '0')}h', 11, textColor);
        t.paint(canvas, Offset(x - t.width / 2, plot.bottom + 8));
      }
    }

    // Os outros canais ficam apagados ao fundo.
    for (var c = 0; c < curves.length; c++) {
      if (c == selected) continue;
      canvas.drawPath(
        _linePath(g, curves[c]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = colors[c].withAlpha(80),
      );
    }

    // Canal escolhido: área, linha e pontos.
    final curve = curves[selected];
    final color = colors[selected];
    final line = _linePath(g, curve);
    final area = Path.from(line)
      ..lineTo(plot.right, plot.bottom)
      ..lineTo(plot.left, plot.bottom)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withAlpha(36));
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    for (var i = 0; i < curve.points.length; i++) {
      final p = curve.points[i];
      final o = g.toPixel(p.minute, p.value);
      final active = dragIndex == i;
      canvas.drawCircle(o, active ? 15 : 11, Paint()..color = color);
      canvas.drawCircle(
        o,
        active ? 15 : 11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white,
      );
    }

    // Simulação: linha que anda, com a intensidade de cada canal naquele horário.
    final ph = playhead;
    if (ph != null) {
      final x = g.toPixel(ph, 0).dx;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = textColor
          ..strokeWidth = 2,
      );
      for (var c = 0; c < curves.length; c++) {
        final o = g.toPixel(ph, curves[c].valueAt(ph));
        canvas.drawCircle(o, 6, Paint()..color = colors[c]);
        canvas.drawCircle(
          o,
          6,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white,
        );
      }
      final t = _label(timeLabel(ph), 13, tooltipTextColor);
      final w = t.width + 16;
      final h = t.height + 8;
      var left = x - w / 2;
      if (left < plot.left) left = plot.left;
      if (left + w > size.width) left = size.width - w;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(left, 0, w, h), const Radius.circular(8)),
        Paint()..color = tooltipColor,
      );
      t.paint(canvas, Offset(left + 8, 4));
    }

    // Etiqueta com horário e intensidade do ponto que está sendo arrastado.
    final di = dragIndex;
    if (di != null && di < curve.points.length) {
      final p = curve.points[di];
      final o = g.toPixel(p.minute, p.value);
      final t = _label('${timeLabel(p.minute)} · ${p.value}%', 13,
          tooltipTextColor);
      final w = t.width + 16;
      final h = t.height + 10;
      var left = o.dx - w / 2;
      if (left < plot.left) left = plot.left;
      if (left + w > size.width) left = size.width - w;
      var top = o.dy - 28 - h;
      if (top < 0) top = o.dy + 28;
      final box = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, w, h), const Radius.circular(8));
      canvas.drawRRect(box, Paint()..color = tooltipColor);
      t.paint(canvas, Offset(left + 8, top + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => true;
}
