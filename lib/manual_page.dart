import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'aqua.dart';
import 'controller.dart';

/// Canais do aquário marinho (não há canal vermelho).
const List<Color> channelColors = [
  Color(0xFF6577FF), // Royal Blue
  Color(0xFF38A9FF), // Blue
  Color(0xFF22E3EE), // Ciano
  Color(0xFFF4F8FF), // Branco
  Color(0xFFB97CFF), // Violeta
];

const List<String> channelNames = [
  'Royal Blue',
  'Blue',
  'Ciano',
  'Branco',
  'Violeta',
];

const List<String> channelDetails = [
  '450–465 nm',
  '470 nm',
  '490 nm',
  '6500 K',
  '420 nm',
];

const List<IconData> channelIcons = [
  Icons.nightlight_round,
  Icons.water_drop_outlined,
  Icons.waves,
  Icons.wb_sunny_outlined,
  Icons.auto_awesome,
];

/// Aba "Canais": Controle (sliders ao vivo) e Espectro.
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
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AquaTabs(
          labels: const ['Controle', 'Espectro'],
          selected: _section,
          onChanged: (i) => setState(() => _section = i),
        ),
        const SizedBox(height: 12),
        if (_section == 0) ..._control() else ..._spectrum(),
      ],
    );
  }

  List<Widget> _control() {
    final enabled = c.connected;
    return [
      AquaPanel(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Controle ao vivo (experimental). Ao desligar, a controladora volta ao cronograma.',
                style: TextStyle(color: Aqua.muted, fontSize: 12),
              ),
            ),
            Switch(
              value: c.liveActive,
              onChanged: enabled ? c.setLiveActive : null,
            ),
          ],
        ),
      ),
      for (var i = 0; i < c.live.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          decoration: BoxDecoration(
            color: const Color(0xCC031A30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Aqua.line),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: channelColors[i], width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: channelColors[i].withOpacity(0.35),
                        blurRadius: 10),
                  ],
                ),
                child: Icon(channelIcons[i], color: channelColors[i]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CH${i + 1} - ${channelNames[i]}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: Aqua.text)),
                    Text(channelDetails[i],
                        style: TextStyle(
                            fontSize: 12, color: channelColors[i])),
                    Slider(
                      value: c.live[i].toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      activeColor: channelColors[i],
                      onChanged:
                          enabled ? (v) => c.setLive(i, v.round()) : null,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('${c.live[i]}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Aqua.text)),
              ),
            ],
          ),
        ),
      AquaPanel(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.tune, color: Aqua.cyan),
          title: const Text('Ajuste rápido',
              style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Equalizar canais'),
          trailing: const Icon(Icons.chevron_right),
          onTap: !c.connected
              ? null
              : () {
                  final avg =
                      (c.live.reduce((a, b) => a + b) / c.live.length).round();
                  c.setAllLive(avg);
                },
        ),
      ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: enabled ? () => c.setAllLive(0) : null,
              child: const Text('Apagar tudo'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: enabled ? () => c.setAllLive(100) : null,
              child: const Text('Tudo a 100%'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _spectrum() {
    return [
      AquaPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Espectro de luz'),
            const Text(
              'Mostra como cada canal contribui, com as intensidades ajustadas na aba Controle.',
              style: TextStyle(color: Aqua.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF031426),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Aqua.line),
              ),
              child: CustomPaint(
                painter: _SpectrumPainter(List<int>.of(c.live)),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (var i = 0; i < channelNames.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: channelColors[i], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('${channelNames[i]} ${c.live[i]}%',
                          style: const TextStyle(
                              fontSize: 12, color: Aqua.muted)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }
}

/// Curvas em forma de sino, uma por canal (centros em nm, aproximados).
class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter(this.values);

  final List<int> values;

  static const centers = [457.0, 470.0, 492.0, 560.0, 420.0];
  static const widths = [14.0, 14.0, 18.0, 70.0, 12.0];
  static const lo = 380.0, hi = 700.0;

  @override
  void paint(Canvas canvas, Size size) {
    const l = 10.0, r = 10.0, t = 12.0, b = 22.0;
    final plot = Rect.fromLTRB(l, t, size.width - r, size.height - b);
    final grid = Paint()
      ..color = const Color(0xFF174061)
      ..strokeWidth = 1;
    for (var v = 0; v <= 100; v += 25) {
      final y = plot.bottom - v / 100 * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }
    for (var nm = 400; nm <= 700; nm += 100) {
      final x = plot.left + (nm - lo) / (hi - lo) * plot.width;
      final tp = TextPainter(
        text: TextSpan(
            text: '$nm nm',
            style: const TextStyle(color: Aqua.muted, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 16));
    }
    for (var i = 0; i < 5; i++) {
      final amp = values[i] / 100;
      final path = Path()..moveTo(plot.left, plot.bottom);
      for (var x = 0.0; x <= plot.width; x += 3) {
        final nm = lo + x / plot.width * (hi - lo);
        final d = (nm - centers[i]) / widths[i];
        final y = plot.bottom - amp * _gauss(d) * plot.height;
        path.lineTo(plot.left + x, y);
      }
      path.lineTo(plot.right, plot.bottom);
      path.close();
      canvas.drawPath(
          path, Paint()..color = channelColors[i].withOpacity(0.28));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = channelColors[i],
      );
    }
  }

  double _gauss(double d) => math.exp(-d * d / 2);

  @override
  bool shouldRepaint(covariant _SpectrumPainter old) => true;
}
