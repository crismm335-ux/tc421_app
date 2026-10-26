import 'package:flutter/material.dart';

/// Paleta do Aqua Light: azul-marinho profundo com bordas e brilhos neon,
/// como o painel de referência.
class Aqua {
  static const bg = Color(0xFF030A1C);
  static const panel = Color(0xFF071634);
  static const panelTop = Color(0xFF0B1F45);
  static const field = Color(0xFF040E26);
  static const line = Color(0xFF1A3F7A);
  static const lineBright = Color(0xFF2B63C4);
  static const blue = Color(0xFF1E7BFF);
  static const blueDeep = Color(0xFF1257D9);
  static const cyan = Color(0xFF3FD2FF);
  static const text = Color(0xFFEAF3FF);
  static const muted = Color(0xFF8FA9D4);
  static const green = Color(0xFF47E08A);
  static const teal = Color(0xFF2EE6B0);
  static const amber = Color(0xFFFFB347);
  static const track = Color(0xFF15264A);
  static const button = Color(0xFF0A1C40);
  static const buttonLine = Color(0xFF24508F);
}

/// Mesma cor com outra opacidade (0..1).
Color fade(Color c, double opacity) =>
    c.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

final ThemeData aquaTheme = () {
  final scheme = ColorScheme.fromSeed(
    seedColor: Aqua.blue,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Aqua.blue,
    onPrimary: Colors.white,
    secondary: Aqua.cyan,
    surface: Aqua.bg,
    onSurface: Aqua.text,
    surfaceContainer: Aqua.panel,
    surfaceContainerHigh: Aqua.panelTop,
    surfaceContainerHighest: Aqua.field,
    outlineVariant: Aqua.line,
    onSurfaceVariant: Aqua.muted,
    inverseSurface: Aqua.text,
    onInverseSurface: Aqua.bg,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Aqua.panelTop,
      contentTextStyle: TextStyle(color: Aqua.text),
      behavior: SnackBarBehavior.floating,
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 6,
      inactiveTrackColor: Aqua.track,
      thumbColor: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Aqua.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Aqua.text,
        backgroundColor: Aqua.button,
        side: const BorderSide(color: Aqua.buttonLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Aqua.button,
      selectedColor: const Color(0xFF0E3F86),
      side: const BorderSide(color: Aqua.buttonLine),
      labelStyle: const TextStyle(color: Aqua.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: false,
    ),
  );
}();

/// Cartão com borda azul e fundo em degradê, como os painéis da imagem.
class AquaPanel extends StatelessWidget {
  const AquaPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.color,
    this.borderColor,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;
  final Color? borderColor;

  /// Brilho azul em volta (cartões em destaque).
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        gradient: color == null
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [fade(Aqua.panelTop, 0.92), fade(Aqua.panel, 0.92)],
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? Aqua.line),
        boxShadow: glow
            ? [BoxShadow(color: fade(Aqua.blue, 0.28), blurRadius: 18)]
            : null,
      ),
      child: child,
    );
  }
}

/// Fundo do app: brilho azul no topo sobre o azul-marinho.
class AquaBackground extends StatelessWidget {
  const AquaBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.15),
          radius: 1.35,
          colors: [Color(0xFF0A2C66), Aqua.bg],
          stops: [0, 0.6],
        ),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: Aqua.text)),
      );
}

/// Abas em pílula (Controle | Espectro, Gráfico | Tabela | Simulação...).
class AquaTabs extends StatelessWidget {
  const AquaTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: fade(Aqua.field, 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Aqua.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: i == selected
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF3196FF), Aqua.blueDeep],
                          )
                        : null,
                    boxShadow: i == selected
                        ? [BoxShadow(color: fade(Aqua.blue, 0.55), blurRadius: 14)]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          i == selected ? FontWeight.w600 : FontWeight.w500,
                      color: i == selected ? Colors.white : Aqua.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botão redondo com borda neon (voltar, engrenagem, menu).
class AquaCircleButton extends StatelessWidget {
  const AquaCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fade(Aqua.field, 0.7),
            border: Border.all(color: Aqua.lineBright, width: 1.4),
            boxShadow: [BoxShadow(color: fade(Aqua.blue, 0.35), blurRadius: 10)],
          ),
          child: Icon(icon, color: Aqua.text, size: size * 0.5),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Título centralizado das telas, com voltar à esquerda e engrenagem à direita.
class AquaTitleBar extends StatelessWidget {
  const AquaTitleBar(
      {super.key, required this.title, this.onSettings, this.onBack});

  final String title;
  final VoidCallback? onSettings;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack == null
                ? null
                : AquaCircleButton(
                    icon: Icons.chevron_left,
                    onPressed: onBack,
                    tooltip: 'Voltar'),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w600, color: Aqua.text),
            ),
          ),
          SizedBox(
            width: 44,
            child: onSettings == null
                ? null
                : AquaCircleButton(
                    icon: Icons.settings_outlined,
                    onPressed: onSettings,
                    tooltip: 'Conexão e ajustes'),
          ),
        ],
      ),
    );
  }
}

/// Círculo com ícone e brilho na cor do canal ou do modo.
class AquaOrb extends StatelessWidget {
  const AquaOrb({
    super.key,
    required this.icon,
    required this.color,
    this.size = 52,
    this.active = true,
  });

  final IconData icon;
  final Color color;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = active ? color : Aqua.muted;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [fade(c, 0.22), const Color(0xFF06122C)],
          stops: const [0, 1],
        ),
        border: Border.all(color: fade(c, 0.9), width: 1.6),
        boxShadow: active
            ? [BoxShadow(color: fade(c, 0.45), blurRadius: 14)]
            : null,
      ),
      child: Icon(icon, color: c, size: size * 0.5),
    );
  }
}

/// Liga/desliga azul com bolinha branca, como na imagem.
class AquaSwitch extends StatelessWidget {
  const AquaSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 50,
            height: 28,
            padding: const EdgeInsets.all(3),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: value
                  ? const LinearGradient(
                      colors: [Color(0xFF3196FF), Aqua.blueDeep])
                  : null,
              color: value ? null : Aqua.track,
              border: Border.all(
                  color: value ? const Color(0xFF4AA3FF) : Aqua.buttonLine),
              boxShadow: value
                  ? [BoxShadow(color: fade(Aqua.blue, 0.6), blurRadius: 12)]
                  : null,
            ),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? Colors.white : const Color(0xFF7D93BB),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra deslizante 0..100 com trilho em degradê da cor do canal e bolinha
/// branca brilhante.
class AquaSlider extends StatelessWidget {
  const AquaSlider({
    super.key,
    required this.value,
    required this.color,
    required this.onChanged,
    this.onChangeEnd,
    this.height = 30,
  });

  final int value;
  final Color color;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onChangeEnd;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      int at(double dx) => ((dx - 11) / (w - 22) * 100).round().clamp(0, 100).toInt();
      return Semantics(
        slider: true,
        value: '$value%',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (d) => onChanged!(at(d.localPosition.dx)) : null,
          onTapUp: enabled && onChangeEnd != null
              ? (d) => onChangeEnd!(at(d.localPosition.dx))
              : null,
          onHorizontalDragUpdate:
              enabled ? (d) => onChanged!(at(d.localPosition.dx)) : null,
          onHorizontalDragEnd: enabled && onChangeEnd != null
              ? (_) => onChangeEnd!(value)
              : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: CustomPaint(
              size: Size(w, height),
              painter: _SliderPainter(value / 100, color),
            ),
          ),
        ),
      );
    });
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 11.0;
    final cy = size.height / 2;
    final left = r, right = size.width - r;
    final x = left + (right - left) * t;
    final track = RRect.fromLTRBR(left, cy - 4, right, cy + 4, const Radius.circular(4));
    canvas.drawRRect(track, Paint()..color = Aqua.track);
    if (x > left) {
      final active = RRect.fromLTRBR(left, cy - 4, x, cy + 4, const Radius.circular(4));
      canvas.drawRRect(
        active,
        Paint()
          ..shader = LinearGradient(colors: [fade(color, 0.35), color])
              .createShader(Rect.fromLTRB(left, cy - 4, x, cy + 4)),
      );
    }
    canvas.drawCircle(
        Offset(x, cy),
        r + 3,
        Paint()
          ..color = fade(color, 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset(x, cy), r, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SliderPainter old) =>
      old.t != t || old.color != color;
}

/// Item da barra de navegação de baixo.
class AquaNavItem {
  const AquaNavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Barra de baixo: ícone e texto; o item atual fica ciano e brilha.
class AquaBottomBar extends StatelessWidget {
  const AquaBottomBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onTap,
  });

  final List<AquaNavItem> items;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF2030A1C),
        border: const Border(top: BorderSide(color: Aqua.line)),
        boxShadow: [BoxShadow(color: fade(Aqua.blue, 0.18), blurRadius: 16)],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].icon,
                          size: 26,
                          color: i == selected ? Aqua.cyan : Aqua.muted,
                          shadows: i == selected
                              ? [Shadow(color: fade(Aqua.cyan, 0.8), blurRadius: 10)]
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight:
                                i == selected ? FontWeight.w600 : FontWeight.w500,
                            color: i == selected ? Aqua.cyan : Aqua.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
