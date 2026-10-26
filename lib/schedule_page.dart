import 'package:flutter/material.dart';

import 'aqua.dart';
import 'controller.dart';
import 'curve.dart';
import 'curve_editor.dart';
import 'manual_page.dart' show channelColors, channelNames;

/// Aba "Programação": editor de fotoperíodo.
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

  Tc421Controller get c => widget.controller;

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final uploading = c.uploadProgress != null;
    final message = c.uploadMessage;
    final ch = c.selectedChannel;
    final color = channelColors[ch];
    final point = c.currentCurve.points[c.selectedPoint];
    final endpoint = !c.canRemoveSelected;
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Aqua.muted,
        );

    return ListView(
      physics: _touchingChart ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(12),
      children: [
        AquaTabs(
          labels: const ['Gráfico', 'Tabela', 'Simulação'],
          selected: _section,
          onChanged: (i) => setState(() => _section = i),
        ),
        const SizedBox(height: 12),
        if (_section == 0) ...[
        AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionTitle('Editor de fotoperíodo')),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: color),
                    ),
                    child: Text(channelNames[ch],
                        style: TextStyle(color: color, fontSize: 12)),
                  ),
                ],
              ),
              Text(
                'Arraste os pontos: para os lados muda o horário, para cima e para baixo a intensidade. Os horários andam de 30 em 30 minutos.',
                style: muted,
              ),
              const SizedBox(height: 10),

              // Escolha do canal
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < channelColors.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          avatar: CircleAvatar(
                            radius: 6,
                            backgroundColor: channelColors[i],
                          ),
                          label: Text('CH${i + 1} · ${channelNames[i]}'),
                          selected: ch == i,
                          onSelected: (_) => c.selectChannel(i),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Gráfico
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: const Color(0xFF031426),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Aqua.line),
                ),
                child: RepaintBoundary(
                  child: Listener(
                  onPointerDown: (_) => setState(() => _touchingChart = true),
                  onPointerUp: (_) => setState(() => _touchingChart = false),
                  onPointerCancel: (_) =>
                      setState(() => _touchingChart = false),
                  child: CurveEditor(
                    curves: c.curves,
                    colors: channelColors,
                    selected: ch,
                    selectedPoint: c.selectedPoint,
                    onPointSelected: c.selectPoint,
                    onChanged: c.curvesChanged,
                    playhead: c.simulating ? c.simMinute : null,
                    enabled: !c.simulating,
                  ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Lista de pontos
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < c.pointCount; i++)
                    ChoiceChip(
                      label: Text(
                          'P${i + 1} · ${timeLabel(c.currentCurve.points[i].minute)} · ${c.currentCurve.points[i].value}%'),
                      selected: c.selectedPoint == i,
                      onSelected: (_) => c.selectPoint(i),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Horário e intensidade do ponto escolhido
        AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Horário do ponto (intervalos de 30 min)', style: muted),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Aqua.field,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1C5A88)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    dropdownColor: Aqua.panel,
                    value: point.minute,
                    items: [
                      for (var m = 0; m <= dayMinutes; m += minuteStep)
                        DropdownMenuItem(value: m, child: Text(timeLabel(m))),
                    ],
                    // 00:00 e 24:00 não mudam de horário.
                    onChanged: endpoint || c.simulating
                        ? null
                        : (m) {
                            if (m != null) c.setSelectedPointMinute(m);
                          },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Intensidade: ${point.value}%', style: muted),
              Slider(
                value: point.value.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                activeColor: color,
                onChanged: c.simulating
                    ? null
                    : (v) => c.setSelectedPointValue(v.round()),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar ponto'),
                    onPressed: c.simulating
                        ? null
                        : () {
                            if (!c.addPointNearSelected()) {
                              _toast('Não há horário livre perto deste ponto.');
                            }
                          },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('Remover ponto'),
                    onPressed: c.simulating || !c.canRemoveSelected
                        ? null
                        : c.removeSelectedPoint,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Toque num espaço vazio do gráfico para criar um ponto e dê dois toques (ou segure) num ponto para apagar. Os pontos de 00:00 e 24:00 não saem.',
                style: muted,
              ),
            ],
          ),
        ),

        // Atalhos
        AquaPanel(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Dia (07h–21h)'),
                onPressed: () => c.applyPreset(SchedulePreset.daylight),
              ),
              ActionChip(
                label: const Text('Tudo ligado'),
                onPressed: () => c.applyPreset(SchedulePreset.allOn),
              ),
              ActionChip(
                label: const Text('Tudo desligado'),
                onPressed: () => c.applyPreset(SchedulePreset.allOff),
              ),
              ActionChip(
                label: const Text('Copiar para todos os canais'),
                onPressed: c.copyCurveToAll,
              ),
            ],
          ),
        ),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.upload),
            label: const Text('Enviar para a controladora'),
            onPressed: c.connected && !uploading ? c.uploadSchedule : null,
          ),
        ),
        ],
        if (_section == 1) ...[
        AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Pontos · ${channelNames[ch]}'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < channelColors.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          avatar: CircleAvatar(
                              radius: 6, backgroundColor: channelColors[i]),
                          label: Text('CH${i + 1}'),
                          selected: ch == i,
                          onSelected: (_) => c.selectChannel(i),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < c.pointCount; i++)
                InkWell(
                  onTap: () => c.selectPoint(i),
                  child: Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Aqua.field,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: c.selectedPoint == i ? color : Aqua.line),
                    ),
                    child: Row(
                      children: [
                        Text('P${i + 1}',
                            style: const TextStyle(color: Aqua.muted)),
                        const SizedBox(width: 14),
                        Text(timeLabel(c.currentCurve.points[i].minute),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Aqua.text)),
                        const Spacer(),
                        Text('${c.currentCurve.points[i].value}%',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, color: color)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text('Toque num ponto e ajuste o horário e a intensidade abaixo.',
                  style: muted),
            ],
          ),
        ),
        AquaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Intensidade do ponto P${c.selectedPoint + 1}: ${point.value}%',
                    style: muted),
                Slider(
                  value: point.value.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  activeColor: color,
                  onChanged: c.simulating
                      ? null
                      : (v) => c.setSelectedPointValue(v.round()),
                ),
              ],
            ),
          ),
        ],
        if (_section == 2) ...[
        // Simulação e envio
        AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: Icon(c.simulating ? Icons.stop : Icons.play_arrow),
                      label: Text(c.simulating
                          ? 'Parar ${timeLabel(c.simMinute)}'
                          : 'Simular o dia'),
                      onPressed: !c.connected
                          ? null
                          : (c.simulating
                              ? c.stopSimulation
                              : c.startSimulation),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 15, label: Text('15s')),
                      ButtonSegment(value: 30, label: Text('30s')),
                      ButtonSegment(value: 60, label: Text('60s')),
                    ],
                    selected: {c.simSeconds},
                    onSelectionChanged: c.simulating
                        ? null
                        : (s) => c.setSimSeconds(s.first),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Percorre as 24 h na luminária e depois volta ao cronograma salvo (experimental).',
                style: muted,
              ),
              const SizedBox(height: 12),
              if (uploading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(value: c.uploadProgress),
                ),
              if (message != null && !uploading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(message),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.upload),
                  label: const Text('Enviar para a controladora'),
                  onPressed:
                      c.connected && !uploading ? c.uploadSchedule : null,
                ),
              ),
            ],
          ),
        ),
        ],
      ],
    );
  }
}
