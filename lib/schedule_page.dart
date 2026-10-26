import 'package:flutter/material.dart';

import 'aqua.dart';
import 'channels.dart';
import 'controller.dart';
import 'curve.dart';
import 'curve_editor.dart';

/// Aba "Programação": editor do fotoperíodo (Gráfico, Tabela, Simulação).
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.controller});

  final Tc421Controller controller;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  // Enquanto o dedo está no gráfico, a página não rola (senão o arrasto
  // do ponto briga com a rolagem).
  bool _touchingChart = false;
  int _section = 0; // 0 Gráfico, 1 Tabela, 2 Simulação
  final List<bool> _visible = List.filled(channelColors.length, true);

  Tc421Controller get c => widget.controller;

  void _toast(String text, {String? undoLabel, VoidCallback? undo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: undo == null
            ? null
            : SnackBarAction(
                label: undoLabel ?? 'Desfazer',
                textColor: Aqua.cyan,
                onPressed: undo),
      ));
  }

  /// Guarda as curvas para o botão "Desfazer".
  List<DayCurve> _snapshot() => [for (final k in c.curves) k.copy()];

  void _restore(List<DayCurve> saved, String name) {
    for (var i = 0; i < c.curves.length; i++) {
      c.curves[i] = saved[i];
    }
    c.profileName = name;
    c.selectPoint(0);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: _touchingChart ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      children: [
        AquaTabs(
          labels: const ['Gráfico', 'Tabela', 'Simulação'],
          selected: _section,
          onChanged: (i) => setState(() => _section = i),
        ),
        const SizedBox(height: 14),
        if (_section == 0) ..._graph(),
        if (_section == 1) ..._table(),
        if (_section == 2) ..._simulation(),
      ],
    );
  }

  // ---- Gráfico -------------------------------------------------------------

  Widget _channelChecks() {
    return AquaPanel(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          for (var i = 0; i < channelColors.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == channelColors.length - 1 ? 0 : 6),
                child: _ChannelCheck(
                  index: i,
                  checked: _visible[i],
                  selected: c.selectedChannel == i,
                  onTap: () {
                    setState(() => _visible[i] = true);
                    c.selectChannel(i);
                  },
                  onToggle: () {
                    // Pelo menos um canal fica visível.
                    final others = _visible.where((v) => v).length;
                    if (_visible[i] && others <= 1) return;
                    setState(() => _visible[i] = !_visible[i]);
                    if (!_visible[i] && c.selectedChannel == i) {
                      c.selectChannel(_visible.indexWhere((v) => v));
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chart({bool editable = true}) {
    return AquaPanel(
      padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
      child: Column(
        children: [
          SizedBox(
            height: 270,
            child: RepaintBoundary(
              child: Listener(
                onPointerDown: (_) => setState(() => _touchingChart = true),
                onPointerUp: (_) => setState(() => _touchingChart = false),
                onPointerCancel: (_) => setState(() => _touchingChart = false),
                child: CurveEditor(
                  curves: c.curves,
                  colors: channelColors,
                  selected: c.selectedChannel,
                  selectedPoint: c.selectedPoint,
                  onPointSelected: c.selectPoint,
                  onChanged: () {
                    c.profileName = 'Personalizado';
                    c.curvesChanged();
                  },
                  playhead: c.simulating ? c.simMinute : null,
                  enabled: editable && !c.simulating,
                  visible: _visible,
                ),
              ),
            ),
          ),
          if (editable)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Um toque cria um ponto · dois toques num ponto apagam · arraste para ajustar',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Aqua.muted),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _graph() {
    final ch = c.selectedChannel;
    final color = channelColors[ch];
    final point = c.currentCurve.points[c.selectedPoint];
    final endpoint = !c.canRemoveSelected;
    final busy = c.simulating;
    return [
      _channelChecks(),
      _chart(),

      // Canal e ponto escolhidos
      AquaPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AquaOrb(icon: channelIcons[ch], color: color, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Canal selecionado',
                          style: TextStyle(fontSize: 13, color: Aqua.text)),
                      const SizedBox(height: 2),
                      Text('CH${ch + 1} - ${channelNames[ch]}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ],
                  ),
                ),
                Text('${point.value}%',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600, color: color)),
                const SizedBox(width: 12),
                AquaSwitch(
                  value: c.channelOn[ch],
                  onChanged: (v) => c.setChannelOn(ch, v),
                ),
              ],
            ),
            if (!c.channelOn[ch])
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Canal desligado: vai para a controladora com 0% o dia todo.',
                  style: TextStyle(fontSize: 12, color: Aqua.amber),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horário com setas de 30 em 30 min
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Horário',
                          style: TextStyle(fontSize: 13, color: Aqua.text)),
                      const SizedBox(height: 6),
                      Container(
                        height: 48,
                        padding: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          color: Aqua.field,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Aqua.buttonLine),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(timeLabel(point.minute),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      color: Aqua.text)),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StepArrow(
                                  icon: Icons.keyboard_arrow_up,
                                  onTap: endpoint || busy
                                      ? null
                                      : () => c.stepSelectedPoint(1),
                                ),
                                _StepArrow(
                                  icon: Icons.keyboard_arrow_down,
                                  onTap: endpoint || busy
                                      ? null
                                      : () => c.stepSelectedPoint(-1),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Intensidade',
                          style: TextStyle(fontSize: 13, color: color)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            Expanded(
                              child: AquaSlider(
                                value: point.value,
                                color: color,
                                onChanged: busy
                                    ? null
                                    : (v) {
                                        c.profileName = 'Personalizado';
                                        c.setSelectedPointValue(v);
                                      },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 48,
                              child: Text('${point.value}%',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Aqua.text)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (endpoint)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Os pontos de 00:00 e 24:00 só mudam de intensidade.',
                    style: TextStyle(fontSize: 12, color: Aqua.muted)),
              ),
          ],
        ),
      ),

      // Ações
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 3.1,
        children: [
          _ActionButton(
            icon: Icons.add,
            label: 'Adicionar ponto',
            onTap: busy
                ? null
                : () {
                    if (!c.addPointNearSelected()) {
                      _toast('Não há horário livre perto deste ponto.');
                    } else {
                      c.profileName = 'Personalizado';
                    }
                  },
          ),
          _ActionButton(
            icon: Icons.delete_outline,
            label: 'Remover ponto',
            onTap: busy || !c.canRemoveSelected
                ? null
                : () {
                    c.profileName = 'Personalizado';
                    c.removeSelectedPoint();
                  },
          ),
          _ActionButton(
            icon: Icons.copy_all_outlined,
            label: 'Duplicar curva',
            onTap: busy ? null : _duplicateSheet,
          ),
          _ActionButton(
            icon: Icons.delete_sweep_outlined,
            label: 'Limpar canal',
            onTap: busy
                ? null
                : () {
                    final saved = _snapshot();
                    final name = c.profileName;
                    c.clearSelectedChannel();
                    _toast('CH${ch + 1} zerado o dia todo.',
                        undo: () => _restore(saved, name));
                  },
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Atalhos
      AquaPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Atalhos para todos os canais'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, preset) in const [
                  ('Dia (07h–21h)', SchedulePreset.daylight),
                  ('Tudo ligado', SchedulePreset.allOn),
                  ('Tudo desligado', SchedulePreset.allOff),
                ])
                  ActionChip(
                    label: Text(label),
                    onPressed: busy
                        ? null
                        : () {
                            final saved = _snapshot();
                            final name = c.profileName;
                            c.applyPreset(preset);
                            _toast('Curvas trocadas: $label.',
                                undo: () => _restore(saved, name));
                          },
                  ),
              ],
            ),
          ],
        ),
      ),
      _sendBlock(),
    ];
  }

  void _duplicateSheet() {
    final from = c.selectedChannel;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Aqua.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('Copiar a curva do CH${from + 1} para:',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Aqua.text)),
                ),
                for (var i = 0; i < channelColors.length; i++)
                  if (i != from)
                    ListTile(
                      leading: CircleAvatar(
                          radius: 8, backgroundColor: channelColors[i]),
                      title: Text('CH${i + 1} - ${channelNames[i]}',
                          style: const TextStyle(color: Aqua.text)),
                      onTap: () {
                        Navigator.pop(sheet);
                        final saved = _snapshot();
                        final name = c.profileName;
                        c.copyCurveTo(i);
                        _toast('Curva copiada para o CH${i + 1}.',
                            undo: () => _restore(saved, name));
                      },
                    ),
                ListTile(
                  leading: const Icon(Icons.select_all, color: Aqua.cyan),
                  title: const Text('Todos os canais',
                      style: TextStyle(color: Aqua.text)),
                  onTap: () {
                    Navigator.pop(sheet);
                    final saved = _snapshot();
                    final name = c.profileName;
                    c.copyCurveToAll();
                    c.profileName = 'Personalizado';
                    _toast('Curva copiada para todos os canais.',
                        undo: () => _restore(saved, name));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sendBlock() {
    final uploading = c.uploadProgress != null;
    final message = c.uploadMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (uploading)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: c.uploadProgress,
                minHeight: 6,
                color: Aqua.cyan,
                backgroundColor: Aqua.track,
              ),
            ),
          ),
        if (message != null && !uploading)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(message, style: const TextStyle(color: Aqua.text)),
          ),
        if (!c.connected)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Conecte a luminária para enviar.',
                style: TextStyle(fontSize: 12, color: Aqua.muted)),
          ),
        FilledButton.icon(
          icon: const Icon(Icons.upload),
          label: Text('Enviar "${c.profileName}" para a controladora'),
          onPressed: c.connected && !uploading ? c.uploadSchedule : null,
        ),
      ],
    );
  }

  // ---- Tabela --------------------------------------------------------------

  List<Widget> _table() {
    final ch = c.selectedChannel;
    final color = channelColors[ch];
    final point = c.currentCurve.points[c.selectedPoint];
    return [
      _channelChecks(),
      AquaPanel(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pontos do CH${ch + 1} - ${channelNames[ch]}',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 6),
            for (var i = 0; i < c.pointCount; i++)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => c.selectPoint(i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Aqua.field,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: c.selectedPoint == i ? color : Aqua.line),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text('P${i + 1}',
                            style: const TextStyle(color: Aqua.muted)),
                      ),
                      Text(timeLabel(c.currentCurve.points[i].minute),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Aqua.text)),
                      const Spacer(),
                      Text('${c.currentCurve.points[i].value}%',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      AquaPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'P${c.selectedPoint + 1} · ${timeLabel(point.minute)} · ${point.value}%',
                style: const TextStyle(color: Aqua.text)),
            const SizedBox(height: 6),
            AquaSlider(
              value: point.value,
              color: color,
              onChanged: c.simulating
                  ? null
                  : (v) {
                      c.profileName = 'Personalizado';
                      c.setSelectedPointValue(v);
                    },
            ),
          ],
        ),
      ),
      _sendBlock(),
    ];
  }

  // ---- Simulação -----------------------------------------------------------

  List<Widget> _simulation() {
    final m = c.simulating ? c.simMinute : null;
    return [
      _channelChecks(),
      _chart(editable: false),
      AquaPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m != null) ...[
              Text('Agora na luminária: ${timeLabel(m)}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Aqua.text)),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < channelColors.length; i++)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                              '${c.channelOn[i] ? c.curves[i].valueAt(m) : 0}%',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: channelColors[i])),
                          Text('CH${i + 1}',
                              style: const TextStyle(
                                  fontSize: 12, color: Aqua.muted)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: Icon(c.simulating ? Icons.stop : Icons.play_arrow),
                    label: Text(c.simulating ? 'Parar' : 'Simular o dia'),
                    onPressed: !c.connected
                        ? null
                        : (c.simulating ? c.stopSimulation : c.startSimulation),
                  ),
                ),
                const SizedBox(width: 10),
                AquaTabsSmall(
                  labels: const ['15s', '30s', '60s'],
                  selected: const [15, 30, 60].indexOf(c.simSeconds),
                  onChanged: c.simulating
                      ? null
                      : (i) => c.setSimSeconds(const [15, 30, 60][i]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              c.connected
                  ? 'A luminária percorre as 24 h no tempo escolhido e depois volta ao cronograma salvo nela (experimental).'
                  : 'Conecte a luminária para simular o dia nela.',
              style: const TextStyle(fontSize: 12, color: Aqua.muted),
            ),
          ],
        ),
      ),
    ];
  }
}

/// Seletor pequeno em pílula (15s | 30s | 60s).
class AquaTabsSmall extends StatelessWidget {
  const AquaTabsSmall({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onChanged == null ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Aqua.field,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Aqua.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              GestureDetector(
                onTap: onChanged == null ? null : () => onChanged!(i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: i == selected ? Aqua.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(labels[i],
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: i == selected ? Colors.white : Aqua.muted)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Caixinha de canal (CH1..CH5) com quadradinho de marcar.
class _ChannelCheck extends StatelessWidget {
  const _ChannelCheck({
    required this.index,
    required this.checked,
    required this.selected,
    required this.onTap,
    required this.onToggle,
  });

  final int index;
  final bool checked;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = channelColors[index];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Aqua.field,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : Aqua.line, width: selected ? 1.6 : 1),
          boxShadow: selected
              ? [BoxShadow(color: fade(color, 0.35), blurRadius: 10)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: checked ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: checked
                      ? Icon(Icons.check,
                          size: 13,
                          color: index == 3 ? Aqua.bg : Colors.white)
                      : null,
                ),
              ),
            ),
            Flexible(
              child: Text('CH${index + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(fontSize: 13, color: Aqua.text)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Icon(icon,
          size: 20, color: onTap == null ? fade(Aqua.muted, 0.4) : Aqua.text),
    );
  }
}

/// Botão grande com borda (Adicionar ponto, Remover ponto...).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [fade(Aqua.panelTop, 0.92), fade(Aqua.panel, 0.92)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Aqua.line),
            ),
            child: Row(
              children: [
                Icon(icon, color: Aqua.text, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: Aqua.text)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
