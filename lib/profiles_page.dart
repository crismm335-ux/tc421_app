import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aqua.dart';
import 'controller.dart';
import 'curve.dart';
import 'manual_page.dart' show channelColors;

const Map<String, String> _profileNotes = {
  'Recife Natural': 'Equilíbrio perfeito',
  'Predominância Azul': 'Ideal para corais SPS',
  'SPS Dominante': 'Alto PAR e espectro amplo',
  'LPS Dominante': 'Luz mais suave e uniforme',
  'Apenas Azuis': 'Tons azuis e violeta',
};

/// Aba "Perfis": Biblioteca (perfis prontos) e Meus Perfis (JSON).
class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key, required this.controller});

  final Tc421Controller controller;

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  int _section = 0;

  Tc421Controller get controller => widget.controller;

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AquaTabs(
          labels: const ['Biblioteca', 'Meus Perfis'],
          selected: _section,
          onChanged: (i) => setState(() => _section = i),
        ),
        const SizedBox(height: 12),
        if (_section == 0) ...[
          for (final name in profilePeaks.keys)
            _ProfileCard(
              name: name,
              note: _profileNotes[name] ?? '',
              current: controller.profileName == name,
              onTap: () {
                controller.applyProfile(name);
                _toast(context, 'Perfil $name aplicado.');
              },
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Aplicar um perfil substitui as curvas dos cinco canais. Depois ajuste na Programação e envie para a controladora.',
              style: TextStyle(color: Aqua.muted, fontSize: 12),
            ),
          ),
        ] else ...[
          AquaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Personalizado'),
                const Text(
                  'Monte sua curva na Programação. Exportar copia o programa em JSON para guardar; para usar de novo, copie o JSON e toque em Importar.',
                  style: TextStyle(color: Aqua.muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Exportar JSON'),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: controller.exportJson()));
                        if (context.mounted) {
                          _toast(context, 'Programa copiado.');
                        }
                      },
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.paste, size: 18),
                      label: const Text('Importar JSON'),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        final error =
                            controller.importJson(data?.text ?? '');
                        if (context.mounted) {
                          _toast(context, error ?? 'Perfil importado.');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniCurves extends CustomPainter {
  _MiniCurves(this.curves);

  final List<DayCurve> curves;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < curves.length; i++) {
      final path = Path();
      final pts = curves[i].points;
      for (var k = 0; k < pts.length; k++) {
        final x = pts[k].minute / dayMinutes * size.width;
        final y = size.height - 3 - pts[k].value / 100 * (size.height - 6);
        if (k == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = channelColors[i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniCurves old) => false;
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.note,
    required this.current,
    required this.onTap,
  });

  final String name;
  final String note;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final curves = profileCurves(name)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: current ? Aqua.cyan : Aqua.line),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF08294B), Color(0xFF03172A)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Aqua.text)),
                Text(note,
                    style: const TextStyle(color: Aqua.muted, fontSize: 12)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: CustomPaint(
                    painter: _MiniCurves(curves),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: current ? null : onTap,
            child: Text(current ? 'Atual' : 'Aplicar'),
          ),
        ],
      ),
    );
  }
}
