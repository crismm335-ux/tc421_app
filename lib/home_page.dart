import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'aqua.dart';
import 'aquarium.dart';
import 'controller.dart';
import 'curve.dart';
import 'home_info.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.aquarium,
    required this.onGo,
  });

  final Tc421Controller controller;
  final AquariumController aquarium;

  /// 0 início, 1 canais, 2 programação, 3 perfis, 4 equipamentos,
  /// 5 conexão, 7 animais, 8 testes.
  final void Function(int tab) onGo;

  static const _recife = [80, 70, 48, 30, 40];
  static const _noturno = [6, 4, 0, 0, 5];

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final a = aquarium;
    final masterOn = !(c.liveActive && c.liveMode == 'Desligado');
    final ip = c.manualIp ?? 'rede local';
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Cabeçalho
        SizedBox(
          height: 108,
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 14,
                child: AquaCircleButton(
                    icon: Icons.settings_outlined,
                    onPressed: () => onGo(5),
                    tooltip: 'Conexão e ajustes'),
              ),
              const Positioned(
                top: 14,
                left: 64,
                right: 64,
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'AQUA ',
                        children: [
                          TextSpan(
                              text: 'LIGHT',
                              style: TextStyle(color: Aqua.cyan)),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Color(0xCC000814), blurRadius: 12),
                        ],
                      ),
                    ),
                    SizedBox(height: 2),
                    SizedBox(height: 6),
                    Text('CONTROLE E MONITORAMENTO DO AQUÁRIO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.6,
                            color: Color(0xFFCFE2FF),
                            shadows: [
                              Shadow(color: Color(0xCC000814), blurRadius: 8)
                            ])),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel(
                  icon: Icons.lightbulb_outline,
                  text: 'LUMINÁRIA',
                  color: Aqua.cyan),
              // Conexão + modo
              Transform.translate(
                offset: Offset.zero,
                child: AquaPanel(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => onGo(5),
                          child: Row(
                            children: [
                              Icon(c.connected ? Icons.wifi : Icons.wifi_off,
                                  color: c.connected ? Aqua.cyan : Aqua.muted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        text: 'Luminária ',
                                        children: [
                                          TextSpan(
                                            text: c.connected
                                                ? 'Conectada'
                                                : (c.searching
                                                    ? 'Procurando'
                                                    : 'Sem conexão'),
                                            style: TextStyle(
                                                color: c.connected
                                                    ? Aqua.cyan
                                                    : Aqua.amber),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Aqua.text),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      c.connected ? '● TC421 · $ip' : 'TC421 · toque para conectar',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: c.connected
                                              ? Aqua.green
                                              : Aqua.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.calendar_month_outlined,
                          color: Aqua.text, size: 24),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.liveActive ? 'Modo manual' : 'Modo automático',
                              style: const TextStyle(
                                  fontSize: 13, color: Aqua.text)),
                          const SizedBox(height: 2),
                          Text(
                              c.liveActive
                                  ? (c.liveMode ?? 'Ao vivo')
                                  : 'Fotoperíodo ativo',
                              style: const TextStyle(
                                  fontSize: 12, color: Aqua.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Intensidade + modos
              AquaPanel(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                child: Column(
                  children: [
                    SizedBox(
                      height: 220,
                      // O anel só é redesenhado quando a intensidade muda.
                      child: RepaintBoundary(
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
                                    TextSpan(
                                        text: '%',
                                        style: TextStyle(fontSize: 26)),
                                  ],
                                ),
                                style: const TextStyle(
                                    fontSize: 60,
                                    fontWeight: FontWeight.w700,
                                    color: Aqua.text,
                                    height: 1),
                              ),
                              const SizedBox(height: 8),
                              const Text('INTENSIDADE',
                                  style: TextStyle(
                                      fontSize: 13,
                                      letterSpacing: 1.2,
                                      color: Aqua.muted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Quick(
                          icon: Icons.power_settings_new,
                          color: Aqua.cyan,
                          title: 'MASTER',
                          sub: masterOn ? 'Ligado' : 'Desligado',
                          active: masterOn,
                          subColor: masterOn ? Aqua.green : Aqua.muted,
                          onTap: !c.connected
                              ? null
                              : () {
                                  if (masterOn) {
                                    c.applyLiveLevels(
                                        const [0, 0, 0, 0, 0], 'Desligado');
                                  } else {
                                    c.backToSchedule();
                                  }
                                },
                        ),
                        _Quick(
                          icon: Icons.wb_sunny_outlined,
                          color: const Color(0xFFFFC53D),
                          title: 'Modo Recife',
                          sub: c.liveMode == 'Recife' ? 'Ativo' : 'Perfil ativo',
                          active: c.liveMode == 'Recife' || !c.liveActive,
                          onTap: !c.connected
                              ? null
                              : () => c.applyLiveLevels(_recife, 'Recife'),
                        ),
                        _Quick(
                          icon: Icons.nightlight_round,
                          color: const Color(0xFF5D8BFF),
                          title: 'Modo Noturno',
                          sub: c.liveMode == 'Noturno' ? 'Ligado' : 'Desligado',
                          active: c.liveMode == 'Noturno',
                          onTap: !c.connected
                              ? null
                              : () => c.applyLiveLevels(_noturno, 'Noturno'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Resumo do dia
              _DaySummary(controller: c, onTap: () => onGo(2)),

              const SizedBox(height: 10),
              // Informações do aquário escolhidas pelo usuário
              HomeAquariumInfo(
                aquarium: a,
                onGo: onGo,
                // Conexão do aquário (ESP32), logo abaixo do título
                connection: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onGo(4),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
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
                                        fontWeight: FontWeight.w600,
                                        color: Aqua.text)),
                                Text(
                                    a.connected
                                        ? '● ESP32${a.ip.isEmpty ? '' : ' · ${a.ip}'}'
                                        : 'Toque para conectar o ESP32',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: a.connected
                                            ? Aqua.green
                                            : Aqua.muted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Aqua.muted),
                        ],
                      ),
                    ),
                  ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Botão de modo: círculo brilhante, título e situação.
class _Quick extends StatelessWidget {
  const _Quick({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.onTap,
    this.active = false,
    this.subColor = Aqua.muted,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  final bool active;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                AquaOrb(icon: icon, color: color, size: 62, active: true),
                const SizedBox(height: 8),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Aqua.text)),
                const SizedBox(height: 2),
                Text(sub,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: subColor)),
              ],
            ),
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
    var dusk = last;
    for (var i = avg.length - 1; i >= 0; i--) {
      if (avg[i] >= avg[peakI] * 0.5) {
        dusk = i;
        break;
      }
    }
    final has = first >= 0;
    final moments = has
        ? [first * minuteStep, peakI * minuteStep, dusk * minuteStep, last * minuteStep]
        : <int>[];
    return AquaPanel(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Resumo do dia',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Aqua.text)),
              ),
              TextButton(
                onPressed: onTap,
                child: const Text('Ver programação  ›',
                    style: TextStyle(color: Aqua.cyan)),
              ),
            ],
          ),
          if (!has)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text('Nenhum ponto ligado no cronograma.',
                  style: TextStyle(color: Aqua.muted)),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                height: 34,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _DayBarPainter(moments),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  _Moment(timeLabel(moments[0]), 'Amanhecer'),
                  _Moment(timeLabel(moments[1]), 'Pico'),
                  _Moment(timeLabel(moments[2]), 'Entardecer'),
                  _Moment(timeLabel(moments[3]), 'Noite'),
                ],
              ),
            ),
          ],
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
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(time,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Aqua.text)),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Aqua.muted)),
          ],
        ),
      );
}

/// Barra do dia: sol à esquerda, lua à direita, pontos em amanhecer, pico,
/// entardecer e noite. Os pontos ficam alinhados com as quatro colunas.
class _DayBarPainter extends CustomPainter {
  _DayBarPainter(this.moments);

  final List<int> moments;

  static const _dots = [
    Color(0xFFFFB347),
    Color(0xFF3FD2FF),
    Color(0xFFFFC53D),
    Color(0xFFB06BFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final colW = size.width / 4;
    final xs = [for (var i = 0; i < 4; i++) colW * i + colW / 2];
    final bar = Rect.fromLTRB(xs.first, cy - 3, xs.last, cy + 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(colors: [
          Color(0xFFFFB347),
          Color(0xFF3FD2FF),
          Color(0xFF3FD2FF),
          Color(0xFFFFC53D),
          Color(0xFFB06BFF),
        ]).createShader(bar),
    );
    // Sol e lua nas pontas
    _icon(canvas, Icons.wb_sunny, Offset(xs.first - 26, cy), const Color(0xFFFFC53D));
    _icon(canvas, Icons.brightness_3, Offset(xs.last + 26, cy), const Color(0xFFDDE6FF));
    for (var i = 0; i < 4; i++) {
      final o = Offset(xs[i], cy);
      canvas.drawCircle(o, 10, Paint()..color = fade(_dots[i], 0.3));
      canvas.drawCircle(o, 7, Paint()..color = _dots[i]);
      canvas.drawCircle(
          o,
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white);
    }
  }

  void _icon(Canvas canvas, IconData icon, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
            fontSize: 22,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DayBarPainter old) =>
      old.moments.length != moments.length ||
      [for (var i = 0; i < moments.length; i++) old.moments[i] != moments[i]]
          .any((x) => x);
}

/// Arco de intensidade (270°) com brilho.
class _GaugePainter extends CustomPainter {
  _GaugePainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 16;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = 0.75 * math.pi;
    const sweep = 1.5 * math.pi;
    // Disco escuro no meio
    canvas.drawCircle(
      center,
      radius - 12,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF0C2250), Color(0xFF050F27)],
        ).createShader(Rect.fromCircle(center: center, radius: radius - 12)),
    );
    canvas.drawCircle(
      center,
      radius - 12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Aqua.line,
    );
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF0E2550),
    );
    if (value > 0) {
      final v = sweep * value.clamp(0.0, 1.0);
      canvas.drawArc(
        rect,
        start,
        v,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round
          ..color = fade(Aqua.cyan, 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawArc(
        rect,
        start,
        v,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..shader = const SweepGradient(
            startAngle: start,
            endAngle: start + sweep,
            colors: [Aqua.blueDeep, Aqua.blue, Aqua.cyan],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value;
}

/// Divisor de seção do Início: ícone, nome e linha na cor da seção.
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final Color color;

  /// Texto de um link à direita (ex.: "Personalizar").
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fade(color, 0.12),
              border: Border.all(color: fade(color, 0.7)),
              boxShadow: [BoxShadow(color: fade(color, 0.35), blurRadius: 8)],
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Text(text,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [fade(color, 0.6), fade(color, 0)]),
              ),
            ),
          ),
          if (action != null)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune, size: 16, color: Aqua.cyan),
                    const SizedBox(width: 6),
                    Text(action!,
                        style: const TextStyle(fontSize: 13, color: Aqua.cyan)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
