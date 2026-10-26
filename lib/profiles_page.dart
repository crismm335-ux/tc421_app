import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aqua.dart';
import 'channels.dart';
import 'controller.dart';
import 'curve.dart';

/// Aba "Perfis": Biblioteca (perfis prontos) e Meus Perfis.
class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key, required this.controller, required this.onGo});

  final Tc421Controller controller;

  /// Mesmos códigos do app: 2 abre a Programação.
  final void Function(int code) onGo;

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  int _section = 0;
  final TextEditingController _name = TextEditingController();

  Tc421Controller get controller => widget.controller;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toast(String text, {VoidCallback? undo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: undo == null
            ? null
            : SnackBarAction(
                label: 'Desfazer', textColor: Aqua.cyan, onPressed: undo),
      ));
  }

  /// Aplica e oferece desfazer.
  void _apply(String name, VoidCallback apply) {
    final saved = [for (final k in controller.curves) k.copy()];
    final before = controller.profileName;
    apply();
    _toast('Perfil $name aplicado. Envie pela Programação.', undo: () {
      for (var i = 0; i < controller.curves.length; i++) {
        controller.curves[i] = saved[i];
      }
      controller.profileName = before;
      controller.selectPoint(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      children: [
        AquaTabs(
          labels: const ['Biblioteca', 'Meus Perfis'],
          selected: _section,
          onChanged: (i) => setState(() => _section = i),
        ),
        const SizedBox(height: 14),
        if (_section == 0) ..._library() else ..._mine(),
      ],
    );
  }

  List<Widget> _library() {
    var seed = 3;
    return [
      for (final name in profilePeaks.keys)
        _ProfileCard(
          title: name,
          note: profileNotes[name] ?? '',
          curves: profileCurves(name)!,
          seed: seed += 5,
          current: controller.profileName == name,
          onApply: () => _apply(name, () => controller.applyProfile(name)),
        ),
      _CustomCard(onCreate: () => widget.onGo(2)),
    ];
  }

  List<Widget> _mine() {
    final mine = controller.myProfiles;
    return [
      AquaPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Salvar a programação atual'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    maxLength: 30,
                    style: const TextStyle(color: Aqua.text),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: controller.profileName == 'Personalizado'
                          ? 'Nome do perfil'
                          : controller.profileName,
                      hintStyle: const TextStyle(color: Aqua.muted),
                      filled: true,
                      fillColor: Aqua.field,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Aqua.buttonLine),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Aqua.cyan),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Salvar'),
                  onPressed: () async {
                    final typed = _name.text.trim();
                    final name = typed.isNotEmpty
                        ? typed
                        : (controller.profileName == 'Personalizado'
                            ? 'Meu perfil'
                            : controller.profileName);
                    FocusScope.of(context).unfocus();
                    await controller.saveCurrentProfile(name);
                    _name.clear();
                    if (mounted) _toast('Perfil "$name" salvo.');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      if (mine.isEmpty)
        const AquaPanel(
          child: Row(
            children: [
              Icon(Icons.star_border_rounded, color: Aqua.cyan, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nenhum perfil salvo ainda. Ajuste a curva na Programação e salve aqui para trocar com um toque.',
                  style: TextStyle(color: Aqua.muted),
                ),
              ),
            ],
          ),
        ),
      for (var i = 0; i < mine.length; i++)
        _ProfileCard(
          title: mine[i].name,
          note: '${mine[i].curves.fold<int>(0, (n, k) => n + k.points.length)} pontos nos 5 canais',
          curves: mine[i].curves,
          seed: 40 + i * 3,
          current: controller.profileName == mine[i].name,
          onApply: () => _apply(
              mine[i].name, () => controller.applySavedProfile(mine[i])),
          onDelete: () => _confirmDelete(mine[i]),
        ),
      AquaPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Copiar e colar (JSON)'),
            const Text(
              'Exportar copia a programação para guardar ou mandar para alguém. Para usar uma copiada, toque em Importar.',
              style: TextStyle(color: Aqua.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Exportar'),
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: controller.exportJson()));
                      if (mounted) _toast('Programação copiada.');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.paste, size: 18),
                    label: const Text('Importar'),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      final error = controller.importJson(data?.text ?? '');
                      if (mounted) _toast(error ?? 'Perfil importado.');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _confirmDelete(SavedProfile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Aqua.panel,
        title: Text('Apagar "${p.name}"?'),
        content: const Text('O perfil sai da lista. A programação atual não muda.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.deleteSavedProfile(p);
      if (mounted) _toast('Perfil apagado.');
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.title,
    required this.note,
    required this.curves,
    required this.seed,
    required this.current,
    required this.onApply,
    this.onDelete,
  });

  final String title;
  final String note;
  final List<DayCurve> curves;
  final int seed;
  final bool current;
  final VoidCallback onApply;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return AquaPanel(
      padding: EdgeInsets.zero,
      borderColor: current ? Aqua.cyan : null,
      glow: current,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Aqua.text)),
                      const SizedBox(height: 2),
                      Text(note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Aqua.muted, fontSize: 13)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 34,
                        child: CustomPaint(
                          painter: _MiniCurves(curves),
                          size: Size.infinite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        minimumSize: const Size(0, 38),
                      ),
                      onPressed: onApply,
                      child: Text(current ? 'Em uso' : 'Aplicar'),
                    ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: 'Apagar perfil',
                        icon: const Icon(Icons.delete_outline,
                            color: Aqua.muted, size: 20),
                        onPressed: onDelete,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomCard extends StatelessWidget {
  const _CustomCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return AquaPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 64,
            decoration: BoxDecoration(
              color: Aqua.field,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Aqua.line),
            ),
            child: const Icon(Icons.edit_outlined, color: Aqua.text, size: 30),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Personalizado',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Aqua.text)),
                SizedBox(height: 2),
                Text('Crie seu próprio perfil',
                    style: TextStyle(color: Aqua.muted, fontSize: 13)),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              minimumSize: const Size(0, 38),
            ),
            onPressed: onCreate,
            child: const Text('Criar'),
          ),
        ],
      ),
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
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round
          ..color = channelColors[i].withAlpha(70)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
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
  bool shouldRepaint(covariant _MiniCurves old) => true;
}
