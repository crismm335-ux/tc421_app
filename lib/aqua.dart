import 'package:flutter/material.dart';

/// Paleta do Aqua Light (aquário marinho).
class Aqua {
  static const bg = Color(0xFF020B18);
  static const panel = Color(0xFF061A30);
  static const field = Color(0xFF03172A);
  static const line = Color(0xFF12456F);
  static const blue = Color(0xFF087DFF);
  static const cyan = Color(0xFF19D9FF);
  static const text = Color(0xFFEAF6FF);
  static const muted = Color(0xFF94B9D8);
  static const button = Color(0xFF062445);
  static const buttonLine = Color(0xFF17629A);
}

final ThemeData aquaTheme = () {
  final scheme = ColorScheme.fromSeed(
    seedColor: Aqua.blue,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Aqua.blue,
    onPrimary: Colors.white,
    surface: Aqua.bg,
    onSurface: Aqua.text,
    surfaceContainer: Aqua.panel,
    surfaceContainerHighest: Aqua.field,
    outlineVariant: const Color(0xFF174061),
    onSurfaceVariant: Aqua.muted,
    inverseSurface: Aqua.text,
    onInverseSurface: Aqua.bg,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xF5020B18),
      indicatorColor: const Color(0xFF064B89),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, color: Aqua.text),
      ),
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
      selectedColor: const Color(0xFF034578),
      side: const BorderSide(color: Aqua.buttonLine),
      labelStyle: const TextStyle(color: Aqua.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: false,
    ),
  );
}();

/// Cartão com borda e fundo em degradê, como os painéis do Aqua Light.
class AquaPanel extends StatelessWidget {
  const AquaPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        gradient: color == null
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF061C32), Color(0xFF031326)],
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Aqua.line),
      ),
      child: child,
    );
  }
}

/// Fundo do app: brilho azul no topo.
class AquaBackground extends StatelessWidget {
  const AquaBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.1),
          radius: 1.3,
          colors: [Color(0xFF073E78), Aqua.bg],
          stops: [0, 0.55],
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
                fontSize: 18, fontWeight: FontWeight.w700, color: Aqua.text)),
      );
}

/// Abas em "pílula" (Controle | Espectro, Gráfico | Tabela | Simulação...).
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
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF031426),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Aqua.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? Aqua.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight:
                          i == selected ? FontWeight.w700 : FontWeight.w500,
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

/// Título centralizado das telas internas, com engrenagem para "Mais".
class AquaTitleBar extends StatelessWidget {
  const AquaTitleBar(
      {super.key, required this.title, this.onSettings, this.onBack});

  final String title;
  final VoidCallback? onSettings;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.chevron_left, color: Aqua.text),
                    onPressed: onBack,
                  ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Aqua.text),
            ),
          ),
          SizedBox(
            width: 44,
            child: onSettings == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Aqua.text),
                    onPressed: onSettings,
                  ),
          ),
        ],
      ),
    );
  }
}
