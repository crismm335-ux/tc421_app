import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'aqua.dart';
import 'aquarium.dart';
import 'controller.dart';
import 'curve.dart';
import 'equipment_page.dart' show SensorCard;

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.aquarium,
    required this.onGo,
  });

  final Tc421Controller controller;
  final AquariumController aquarium;

  /// 0 início, 1 canais, 2 programação, 3 perfis, 4 aquário, 5 conexão.
  final void Function(int tab) onGo;

  static const _recife = [80, 70, 48, 30, 40];
  static const _noturno = [6, 4, 0, 0, 5];

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final a = aquarium;
    final masterOn = !(c.liveActive && c.liveMode == 'Desligado');
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        // Cabeçalho
        const SizedBox(height: 4),
        Text.rich(
          const TextSpan(
            text: 'AQUA ',
            children: [
              TextSpan(text: 'LIGHT', style: TextStyle(color: Aqua.cyan)),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: Aqua.text,
          ),
        ),
        const Text('CONTROLADORA DO AQUÁRIO MARINHO',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 11, letterSpacing: 1.5, color: Aqua.muted)),
        const SizedBox(height: 14),

        // Conexão + modo
        AquaPanel(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(c.connected ? Icons.wifi : Icons.wifi_off,
                  color: c.connected ? Aqua.cyan : Aqua.muted),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => onGo(5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          c.connected
                              ? 'Luminária conectada'
                              : (c.searching
                                  ? 'Procurando...'
                                  : 'Luminária sem conexão'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: Aqua.text)),
                      Text(
                          c.connected
                              ? '● ${c.manualIp ?? 'rede local'}'
                              : 'Toque para conectar',
                          style: TextStyle(
                              fontSize: 12,
                              color: c.connected
                                  ? const Color(0xFF47E08A)
                                  : Aqua.muted)),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.calendar_month_outlined, color: Aqua.cyan),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.liveActive ? 'Modo manual' : 'Modo automático',
                      style: const TextStyle(
                          fontSize: 12, color: Aqua.text)),
                  Text(c.liveActive ? (c.liveMode ?? 'Ao vivo') : 'Fotoperíodo ativo',
                      style:
                          const TextStyle(fontSize: 11, color: Aqua.muted)),
                ],
              ),
            ],
          ),
        ),

        // Intensidade
        SizedBox(
          height: 210,
          child: CustomPaint(
            painter: _GaugePainter(c.currentIntensity / 100),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      text: '${c.currentIntensity}',
                      children: const [
                        TextSpan(text: '%', style: TextStyle(fontSize: 22)),
                      ],
                    ),
                    style: const TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.w800,
                        color: Aqua.text),
                  ),
                  const Text('INTENSIDADE',
                      style: TextStyle(
                          fontSize: 12, letterSpacing: 1, color: Aqua.muted)),
                ],
              ),
            ),
          ),
        ),

        // Atalhos
        Row(
          children: [
            _Quick(
              icon: Icons.power_settings_new,
              title: 'MASTER',
              sub: masterOn ? 'Ligado' : 'Desligado',
              subColor: masterOn ? const Color(0xFF47E08A) : Aqua.muted,
              onTap: !c.connected
                  ? null
                  : () {
                      if (masterOn) {
                        c.applyLiveLevels(const [0, 0, 0, 0, 0], 'Desligado');
                      } else {
                        c.backToSchedule();
                      }
                    },
            ),
            _Quick(
              icon: Icons.wb_sunny_outlined,
              title: 'Modo Recife',
              sub: c.liveMode == 'Recife' ? 'Ativo' : 'Perfil ativo',
              iconColor: const Color(0xFF38A9FF),
              onTap: !c.connected
                  ? null
                  : () => c.applyLiveLevels(_recife, 'Recife'),
            ),
            _Quick(
              icon: Icons.nightlight_round,
              title: 'Modo Noturno',
              sub: c.liveMode == 'Noturno' ? 'Ligado' : 'Desligado',
              iconColor: const Color(0xFFB97CFF),
              onTap: !c.connected
                  ? null
                  : () => c.applyLiveLevels(_noturno, 'Noturno'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Resumo do dia
        _DaySummary(controller: c, onTap: () => onGo(2)),

        // Conexão do aquário (ESP32)
        AquaPanel(
          padding: const EdgeInsets.all(14),
          child: InkWell(
            onTap: () => onGo(4),
            child: Row(
              children: [
                Icon(a.connected ? Icons.water : Icons.water_outlined,
                    color: a.connected ? Aqua.cyan : Aqua.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          a.connected
                              ? 'Aquário conectado'
                              : 'Aquário sem conexão',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: Aqua.text)),
                      Text(
                          a.connected
                              ? '● ESP32${a.ip.isEmpty ? '' : ' · ${a.ip}'}'
                              : 'Toque para conectar o ESP32',
                          style: TextStyle(
                              fontSize: 12,
                              color: a.connected
                                  ? const Color(0xFF47E08A)
                                  : Aqua.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Aqua.muted),
              ],
            ),
          ),
        ),

        // Aquário
        if (a.connected && a.alarms.isNotEmpty)
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
        if (!a.connected)
          AquaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Seu aquário'),
                Text(a.status, style: const TextStyle(color: Aqua.muted)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.water_outlined, size: 18),
                  label: Text(a.ip.isEmpty
                      ? 'Conectar ao aquário'
                      : 'Abrir equipamentos'),
                  onPressed: () => onGo(4),
                ),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              SensorCard('Temperatura', a.temp, '°C', 1,
                  warn: a.temp == null),
              const SizedBox(width: 8),
              SensorCard('pH', a.ph, '', 2,
                  note: a.adsOk ? (a.phCal ? null : 'calibrar') : 'sem ADS'),
              const SizedBox(width: 8),
              SensorCard('Salinidade', a.salinity, 'ppt', 1,
                  note:
                      a.adsOk ? (a.ecCal ? null : 'calibrar') : 'sem ADS'),
            ],
          ),
          const SizedBox(height: 12),
          AquaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Níveis de água'),
                _LevelRow(
                  'Sump',
                  a.tpaMinLevel
                      ? 'Nível mínimo'
                      : (a.atoSumpLow ? 'Baixo, repondo' : 'Normal'),
                  warn: a.tpaMinLevel || a.atoSumpLow,
                ),
                _LevelRow(
                  'Galão de reposição',
                  a.atoReservoirEmpty ? 'Vazio' : 'Com água',
                  warn: a.atoReservoirEmpty,
                ),
                if (a.tpaState != 0) ...[
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
                  label: const Text('Abrir equipamentos'),
                  onPressed: () => onGo(4),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.iconColor = Aqua.cyan,
    this.subColor = Aqua.muted,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF05213F),
                  border: Border.all(color: iconColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: iconColor.withOpacity(0.35), blurRadius: 12),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 6),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Aqua.text)),
              Text(sub,
                  style: TextStyle(fontSize: 11, color: subColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.controller, required this.onTap});

  final Tc421Controller controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Média dos canais a cada 30 min.
    final avg = <int>[];
    for (var m = 0; m <= dayMinutes; m += minuteStep) {
      var sum = 0;
      for (final c in controller.curves) {
        sum += c.valueAt(m);
      }
      avg.add((sum / controller.curves.length).round());
    }
    var peakI = 0, first = -1, last = -1;
    for (var i = 0; i < avg.length; i++) {
      if (avg[i] > avg[peakI]) peakI = i;
      if (avg[i] > 0) {
        if (first < 0) first = i;
        last = i;
      }
    }
    String t(int i) => timeLabel(i * minuteStep);
    var dusk = last;
    for (var i = avg.length - 1; i >= 0; i--) {
      if (avg[i] >= avg[peakI] * 0.5) {
        dusk = i;
        break;
      }
    }
    final has = first >= 0;
    return AquaPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Resumo do dia',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Aqua.text)),
              ),
              TextButton(
                  onPressed: onTap, child: const Text('Ver programação ›')),
            ],
          ),
          Container(
            height: 6,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(colors: [
                Color(0xFFFFB347),
                Color(0xFF38A9FF),
                Color(0xFFFFD27A),
                Color(0xFFB97CFF),
              ]),
            ),
          ),
          if (!has)
            const Text('Nenhum ponto ligado no cronograma.',
                style: TextStyle(color: Aqua.muted))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Moment(t(first), 'Amanhecer'),
                _Moment(t(peakI), 'Pico'),
                _Moment(t(dusk), 'Entardecer'),
                _Moment(t(last), 'Noite'),
              ],
            ),
        ],
      ),
    );
  }
}

class _Moment extends StatelessWidget {
  const _Moment(this.time, this.label);

  final String time;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(time,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Aqua.text)),
          Text(label, style: const TextStyle(fontSize: 11, color: Aqua.muted)),
        ],
      );
}

/// Arco de intensidade (270°).
class _GaugePainter extends CustomPainter {
  _GaugePainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = 0.75 * math.pi;
    const sweep = 1.5 * math.pi;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF0A2C4D),
    );
    if (value > 0) {
      canvas.drawArc(
        rect,
        start,
        sweep * value.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..shader = const SweepGradient(
            startAngle: start,
            endAngle: start + sweep,
            colors: [Aqua.blue, Aqua.cyan],
            transform: GradientRotation(0),
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value;
}

class _LevelRow extends StatelessWidget {
  const _LevelRow(this.name, this.state, {this.warn = false});

  final String name;
  final String state;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? const Color(0xFFFFB347) : Aqua.cyan;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(name, style: const TextStyle(color: Aqua.text))),
          Text(state,
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

