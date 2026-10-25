import 'package:flutter/material.dart';

import 'aqua.dart';
import 'aquarium.dart';
import 'connection_panel.dart';
import 'controller.dart';
import 'curve.dart';
import 'equipment_page.dart' show SensorCard;
import 'manual_page.dart' show channelColors, channelNames;

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.aquarium,
    required this.onGo,
  });

  final Tc421Controller controller;
  final AquariumController aquarium;
  final void Function(int tab) onGo;

  @override
  Widget build(BuildContext context) {
    final ch = controller.selectedChannel;
    final a = aquarium;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Aquário: o que mais importa aparece primeiro.
        if (a.connected && a.alarms.isNotEmpty)
          AquaPanel(
            color: const Color(0xFF3A1B12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.warning_amber, color: Color(0xFFFFB347)),
                  SizedBox(width: 8),
                  Text('Alertas',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: Aqua.text)),
                ]),
                const SizedBox(height: 6),
                for (final alarm in a.alarms)
                  Text('• $alarm', style: const TextStyle(color: Aqua.text)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => onGo(4),
                  child: const Text('Abrir o aquário'),
                ),
              ],
            ),
          ),
        AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionTitle('Seu aquário')),
                  Icon(a.connected ? Icons.wifi : Icons.wifi_off,
                      size: 18,
                      color: a.connected ? Aqua.cyan : Aqua.muted),
                ],
              ),
              if (!a.connected) ...[
                Text(a.status, style: const TextStyle(color: Aqua.muted)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => onGo(4),
                  child: Text(a.ip.isEmpty
                      ? 'Conectar a controladora do aquário'
                      : 'Ver conexão'),
                ),
              ] else ...[
                Row(
                  children: [
                    SensorCard('Temperatura', a.temp, '°C', 1,
                        warn: a.temp == null),
                    const SizedBox(width: 8),
                    SensorCard('pH', a.ph, '', 2,
                        note: a.adsOk ? (a.phCal ? null : 'calibrar') : 'sem ADS'),
                    const SizedBox(width: 8),
                    SensorCard('Salinidade', a.salinity, 'ppt', 1,
                        note: a.adsOk ? (a.ecCal ? null : 'calibrar') : 'sem ADS'),
                  ],
                ),
                if (a.tpaState != 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.water_drop_outlined,
                            size: 18, color: Aqua.cyan),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'TPA em andamento: ${const {
                              1: 'retirando água do sump',
                              2: 'aguardando',
                              3: 'repondo água pronta',
                            }[a.tpaState] ?? ''}',
                            style: const TextStyle(color: Aqua.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const Text('Tomadas',
                    style: TextStyle(color: Aqua.muted, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final o in a.outlets)
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () => onGo(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                                color: o.on ? Aqua.cyan : Aqua.line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: o.on
                                      ? Aqua.cyan
                                      : const Color(0xFF2A4258),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(o.name,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          o.on ? Aqua.text : Aqua.muted)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Sump: ${a.atoSumpLow ? 'nível baixo' : 'nível normal'} · Galão de reposição: ${a.atoReservoirEmpty ? 'vazio' : 'com água'}',
                  style: const TextStyle(color: Aqua.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),

        // Destaque
        AquaPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CENTRAL DE ILUMINAÇÃO',
                  style: TextStyle(
                      fontSize: 10, letterSpacing: 2, color: Aqua.muted)),
              const SizedBox(height: 8),
              const Text.rich(
                TextSpan(
                  text: 'Seu recife, sob\n',
                  children: [
                    TextSpan(
                        text: 'a luz ideal.',
                        style: TextStyle(color: Aqua.cyan)),
                  ],
                ),
                style: TextStyle(
                    fontSize: 32,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Aqua.text),
              ),
              const SizedBox(height: 10),
              const Text(
                'Programe o fotoperíodo, ajuste os cinco canais e veja a curva de iluminação ao longo de 24 horas.',
                style: TextStyle(color: Color(0xFFB7D7F2)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Stat('Canal', channelNames[ch]),
                  const SizedBox(width: 8),
                  _Stat('Pontos', '${controller.pointCount}'),
                  const SizedBox(width: 8),
                  _Stat('Média', '${controller.averageIntensity}%'),
                ],
              ),
            ],
          ),
        ),

        // Visão geral
        AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionTitle('Luminária')),
                  Flexible(
                    child: Text('Perfil: ${controller.profileName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Aqua.muted)),
                  ),
                ],
              ),
              const Text('Fotoperíodo de hoje',
                  style: TextStyle(color: Color(0xFFB7DFFF), fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF031426),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Aqua.line),
                ),
                child: CustomPaint(
                  painter: _MiniChart(
                    curve: controller.currentCurve,
                    color: channelColors[ch],
                  ),
                  size: Size.infinite,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => onGo(2),
                    child: const Text('Editar programação'),
                  ),
                  OutlinedButton(
                    onPressed: () => onGo(3),
                    child: const Text('Escolher perfil'),
                  ),
                ],
              ),
            ],
          ),
        ),

        ConnectionPanel(controller: controller),
      ],
    );
  }
}

/// Resumo do aquário no menu inicial.
class _AquariumSummary extends StatelessWidget {
  const _AquariumSummary({required this.aquarium, required this.onGo});

  final AquariumController aquarium;
  final void Function(int tab) onGo;

  @override
  Widget build(BuildContext context) {
    final a = aquarium;
    if (!a.connected) {
      return AquaPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Aquário'),
            Text(a.status, style: const TextStyle(color: Aqua.muted)),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.water_outlined, size: 18),
              label: Text(a.ip.isEmpty ? 'Conectar ao aquário' : 'Abrir o aquário'),
              onPressed: () => onGo(4),
            ),
          ],
        ),
      );
    }
    final running = a.tpaState != 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (a.alarms.isNotEmpty)
          AquaPanel(
            color: const Color(0xFF3A1B12),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.warning_amber, color: Color(0xFFFFB347)),
                  SizedBox(width: 8),
                  Text('Alertas',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: Aqua.text)),
                ]),
                const SizedBox(height: 6),
                for (final alarm in a.alarms)
                  Text('• $alarm', style: const TextStyle(color: Aqua.text)),
              ],
            ),
          ),
        Row(
          children: [
            SensorCard('Temperatura', a.temp, '°C', 1, warn: a.temp == null),
            const SizedBox(width: 8),
            SensorCard('pH', a.ph, '', 2,
                note: a.adsOk ? (a.phCal ? null : 'calibrar') : 'sem ADS'),
            const SizedBox(width: 8),
            SensorCard('Salinidade', a.salinity, 'ppt', 1,
                note: a.adsOk ? (a.ecCal ? null : 'calibrar') : 'sem ADS'),
          ],
        ),
        const SizedBox(height: 12),
        AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Equipamentos'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in a.outlets)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Aqua.field,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: o.on ? Aqua.cyan : Aqua.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color:
                                  o.on ? Aqua.cyan : const Color(0xFF2A4258),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(o.name,
                              style: const TextStyle(
                                  fontSize: 12, color: Aqua.text)),
                        ],
                      ),
                    ),
                ],
              ),
              if (running) ...[
                const SizedBox(height: 10),
                Text(
                  switch (a.tpaState) {
                    1 => 'TPA em andamento: retirando água do sump',
                    2 => 'TPA em andamento: aguardando',
                    _ => 'TPA em andamento: repondo água pronta',
                  },
                  style: const TextStyle(color: Aqua.cyan),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.water_outlined, size: 18),
                label: const Text('Abrir o aquário'),
                onPressed: () => onGo(4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xC902172B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF16507D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Aqua.muted, fontSize: 11)),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Aqua.text)),
          ],
        ),
      ),
    );
  }
}

/// Gráfico pequeno, só para olhar.
class _MiniChart extends CustomPainter {
  _MiniChart({required this.curve, required this.color});

  final DayCurve curve;
  final Color color;

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
    for (var h = 0; h <= 24; h += 6) {
      final x = plot.left + h / 24 * plot.width;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      final tp = TextPainter(
        text: TextSpan(
          text: '${h.toString().padLeft(2, '0')}:00',
          style: const TextStyle(color: Aqua.muted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (x - tp.width / 2).clamp(0.0, size.width - tp.width).toDouble();
      tp.paint(canvas, Offset(dx, size.height - 16));
    }
    Offset at(CurvePoint p) => Offset(
          plot.left + p.minute / dayMinutes * plot.width,
          plot.bottom - p.value / 100 * plot.height,
        );
    final path = Path();
    for (var i = 0; i < curve.points.length; i++) {
      final o = at(curve.points[i]);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    for (final p in curve.points) {
      canvas.drawCircle(at(p), 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniChart old) => true;
}
