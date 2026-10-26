import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'aqua.dart';
import 'channels.dart';
import 'controller.dart';

export 'channels.dart';

/// Aba "Canais": Controle (ao vivo) e Espectro.
class ManualPage extends StatefulWidget {
  const ManualPage({super.key, required this.controller});

  final Tc421Controller controller;

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  int _section = 0;

  Tc421Controller get c => widget.controller;

  @override
  void initState() {
    super.initState();
    // Fora do ao vivo, os canais começam no que o cronograma manda agora.
    if (!c.liveActive) c.loadLiveFromSchedule(notify: false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      children: [
        AquaTabs(
          labels: const ['Controle', 'Espectro'],
          selected: _section,
          onChanged: (i) => setState(() => _section = i),
        ),
        const SizedBox(height: 14),
        if (_section == 0) ..._control() else ..._spectrum(),
      ],
    );
  }

  Widget _notice() {
    if (!c.connected) {
      return const _Notice(
        icon: Icons.wifi_off,
        color: Aqua.amber,
        text: 'Luminária sem conexão. Os ajustes ficam só no app até conectar.',
      );
    }
    if (c.liveActive) {
      return _Notice(
        icon: Icons.bolt,
        color: Aqua.cyan,
        text: c.liveMode == null
            ? 'Controle ao vivo ligado.'
            : 'Controle ao vivo: ${c.liveMode}.',
        action: TextButton(
          onPressed: c.backToSchedule,
          child: const Text('Voltar ao cronograma',
              style: TextStyle(color: Aqua.cyan)),
        ),
      );
    }
    return const _Notice(
      icon: Icons.info_outline,
      color: Aqua.muted,
      text: 'Mostrando o cronograma de agora. Mexer num canal liga o controle ao vivo.',
    );
  }

  List<Widget> _control() {
    return [
      _notice(),
      for (var i = 0; i < c.live.length; i++) _ChannelCard(controller: c, index: i),
      AquaPanel(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _quickSheet,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                AquaOrb(icon: Icons.tune, color: Aqua.cyan, size: 44),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ajuste rápido',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Aqua.text)),
                      SizedBox(height: 2),
                      Text('Equalizar canais',
                          style: TextStyle(fontSize: 13, color: Aqua.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Aqua.text),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  void _quickSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Aqua.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        Widget option(IconData icon, String text, VoidCallback action) => ListTile(
              leading: Icon(icon, color: Aqua.cyan),
              title: Text(text, style: const TextStyle(color: Aqua.text)),
              onTap: () {
                Navigator.pop(context);
                action();
              },
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('Ajuste rápido',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Aqua.text)),
                ),
                option(Icons.equalizer, 'Equalizar canais (média)', () {
                  final avg =
                      (c.live.reduce((a, b) => a + b) / c.live.length).round();
                  c.setAllLive(avg);
                }),
                option(Icons.light_mode, 'Tudo a 100%', () => c.setAllLive(100)),
                option(Icons.power_settings_new, 'Apagar tudo', () => c.setAllLive(0)),
                option(Icons.schedule, 'Valores do cronograma agora',
                    c.loadLiveFromSchedule),
                if (c.liveActive)
                  option(Icons.undo, 'Voltar ao cronograma', c.backToSchedule),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _spectrum() {
    final out = c.liveOutput;
    return [
      AquaPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Espectro de saída'),
            const Text(
              'Mistura dos cinco canais com as intensidades da aba Controle.',
              style: TextStyle(color: Aqua.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              height: 230,
              decoration: BoxDecoration(
                color: fade(Aqua.field, 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Aqua.line),
              ),
              child: CustomPaint(
                painter: SpectrumPainter(out),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
      AquaPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Participação de cada canal'),
            const SizedBox(height: 4),
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < out.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${out[i]}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Aqua.text)),
                            const SizedBox(height: 4),
                            Container(
                              height: 80 * out[i] / 100 + 2,
                              decoration: BoxDecoration(
                                color: channelColors[i],
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                      color: fade(channelColors[i], 0.6),
                                      blurRadius: 10)
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('CH${i + 1}',
                                style: const TextStyle(
                                    fontSize: 12, color: Aqua.muted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.text,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: fade(color, 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fade(color, 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: Aqua.text)),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Cartão de um canal: ícone, nome, faixa, barra, chave, % e espectro.
class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.controller, required this.index});

  final Tc421Controller controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final i = index;
    final color = channelColors[i];
    final on = c.channelOn[i];
    return AquaPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Opacity(
        opacity: on ? 1 : 0.5,
        child: Row(
          children: [
            AquaOrb(icon: channelIcons[i], color: color, size: 56, active: on),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CH${i + 1} - ${channelNames[i]}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Aqua.text)),
                  const SizedBox(height: 2),
                  Text(channelDetails[i],
                      style: TextStyle(fontSize: 13, color: color)),
                  const SizedBox(height: 6),
                  AquaSlider(
                    value: c.live[i],
                    color: color,
                    onChanged: on ? (v) => c.setLive(i, v) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AquaSwitch(
                    value: on,
                    onChanged: (v) => c.setChannelOn(i, v),
                  ),
                  const SizedBox(height: 8),
                  Text('${on ? c.live[i] : 0}%',
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          color: Aqua.text)),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 78,
                    height: 34,
                    child: CustomPaint(painter: _MiniSpectrum(i)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _gauss(double d) => math.exp(-d * d / 2);

/// Cor aproximada de um comprimento de onda (380 a 700 nm).
Color wavelengthColor(double nm) {
  const stops = <double>[380, 420, 450, 480, 500, 530, 580, 620, 700];
  const colors = <Color>[
    Color(0xFF6A00FF),
    Color(0xFF7A3BFF),
    Color(0xFF3B5BFF),
    Color(0xFF0090FF),
    Color(0xFF00E0C0),
    Color(0xFF3CFF5A),
    Color(0xFFFFE600),
    Color(0xFFFF7A00),
    Color(0xFFFF1E3C),
  ];
  if (nm <= stops.first) return colors.first;
  for (var k = 1; k < stops.length; k++) {
    if (nm <= stops[k]) {
      final t = (nm - stops[k - 1]) / (stops[k] - stops[k - 1]);
      return Color.lerp(colors[k - 1], colors[k], t)!;
    }
  }
  return colors.last;
}

/// Curvinha do espectro de um canal, no canto do cartão.
class _MiniSpectrum extends CustomPainter {
  _MiniSpectrum(this.channel);

  final int channel;

  @override
  void paint(Canvas canvas, Size size) {
    const lo = 380.0, hi = 700.0;
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 1) {
      final nm = lo + x / size.width * (hi - lo);
      final d = (nm - channelCenters[channel]) / channelWidths[channel];
      path.lineTo(x, size.height - _gauss(d) * (size.height - 3));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    final colors = [
      for (var k = 0; k <= 8; k++) wavelengthColor(lo + k * (hi - lo) / 8)
    ];
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(colors: colors)
            .createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniSpectrum old) => old.channel != channel;
}

/// Espectro somado dos canais, preenchido com as cores da luz visível,
/// com o contorno de cada canal por cima.
class SpectrumPainter extends CustomPainter {
  SpectrumPainter(this.values);

  final List<int> values;

  static const lo = 380.0, hi = 700.0;

  @override
  void paint(Canvas canvas, Size size) {
    const l = 12.0, r = 12.0, t = 14.0, b = 24.0;
    final plot = Rect.fromLTRB(l, t, size.width - r, size.height - b);
    final grid = Paint()
      ..color = fade(Aqua.line, 0.7)
      ..strokeWidth = 1;
    for (var v = 0; v <= 4; v++) {
      final y = plot.bottom - v / 4 * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }
    for (var nm = 400; nm <= 700; nm += 50) {
      final x = plot.left + (nm - lo) / (hi - lo) * plot.width;
      final tp = TextPainter(
        text: TextSpan(
            text: nm == 700 ? '700 nm' : '$nm',
            style: const TextStyle(color: Aqua.muted, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      var dx = x - tp.width / 2;
      if (dx + tp.width > size.width) dx = size.width - tp.width - 2;
      tp.paint(canvas, Offset(dx, size.height - 17));
    }

    double sumAt(double nm) {
      var s = 0.0;
      for (var i = 0; i < 5; i++) {
        s += values[i] / 100 * _gauss((nm - channelCenters[i]) / channelWidths[i]);
      }
      return s;
    }

    var peak = 0.0;
    for (var x = 0.0; x <= plot.width; x += 2) {
      peak = math.max(peak, sumAt(lo + x / plot.width * (hi - lo)));
    }
    if (peak <= 0) {
      final tp = TextPainter(
        text: const TextSpan(
            text: 'Luz apagada',
            style: TextStyle(color: Aqua.muted, fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, plot.center - Offset(tp.width / 2, tp.height / 2));
      return;
    }
    final scale = plot.height / math.max(peak, 1.0);

    final area = Path()..moveTo(plot.left, plot.bottom);
    for (var x = 0.0; x <= plot.width; x += 2) {
      final nm = lo + x / plot.width * (hi - lo);
      area.lineTo(plot.left + x, plot.bottom - sumAt(nm) * scale);
    }
    area
      ..lineTo(plot.right, plot.bottom)
      ..close();
    final colors = [
      for (var k = 0; k <= 12; k++) wavelengthColor(lo + k * (hi - lo) / 12)
    ];
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(colors: colors).createShader(plot),
    );

    for (var i = 0; i < 5; i++) {
      if (values[i] == 0) continue;
      final path = Path();
      for (var x = 0.0; x <= plot.width; x += 2) {
        final nm = lo + x / plot.width * (hi - lo);
        final y = plot.bottom -
            values[i] / 100 * _gauss((nm - channelCenters[i]) / channelWidths[i]) * scale;
        if (x == 0) {
          path.moveTo(plot.left + x, y);
        } else {
          path.lineTo(plot.left + x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = fade(channelColors[i], 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpectrumPainter old) => true;
}
