import 'package:flutter/material.dart';

import 'controller.dart';
import 'curve.dart' show timeLabel;
import 'curve_editor.dart';
import 'manual_page.dart' show channelColors, channelNames;

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key, required this.controller});

  final Tc421Controller controller;

  @override
  Widget build(BuildContext context) {
    final uploading = controller.uploadProgress != null;
    final message = controller.uploadMessage;
    final textStyle = Theme.of(context).textTheme.bodySmall;

    return Column(
      children: [
        // Escolha do canal que está sendo editado.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: [
              for (var c = 0; c < channelColors.length; c++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: CircleAvatar(
                      radius: 6,
                      backgroundColor: channelColors[c],
                    ),
                    label: Text(controller.selectedChannel == c
                        ? '${c + 1} · ${channelNames[c]}'
                        : '${c + 1}'),
                    selected: controller.selectedChannel == c,
                    onSelected: (_) => controller.selectChannel(c),
                  ),
                ),
            ],
          ),
          ),
        ),

        // O gráfico ocupa o espaço que sobra.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: CurveEditor(
              curves: controller.curves,
              colors: channelColors,
              selected: controller.selectedChannel,
              onChanged: controller.curvesChanged,
              playhead: controller.simulating ? controller.simMinute : null,
              enabled: !controller.simulating,
            ),
          ),
        ),

        // Simulação do dia inteiro na luminária.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: Icon(
                      controller.simulating ? Icons.stop : Icons.play_arrow),
                  label: Text(controller.simulating
                      ? 'Parar ${timeLabel(controller.simMinute)}'
                      : 'Simular o dia'),
                  onPressed: !controller.connected
                      ? null
                      : (controller.simulating
                          ? controller.stopSimulation
                          : controller.startSimulation),
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
                selected: {controller.simSeconds},
                onSelectionChanged: controller.simulating
                    ? null
                    : (s) => controller.setSimSeconds(s.first),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Text(
            'Percorre as 24 h na luminária e depois volta ao cronograma salvo (experimental).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Arraste um ponto: para os lados muda o horário, para cima e para baixo muda a intensidade. '
            'Toque num espaço vazio para criar um ponto; segure um ponto para apagar.',
            style: textStyle,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Dia (07h–21h)'),
                onPressed: () =>
                    controller.applyPreset(SchedulePreset.daylight),
              ),
              ActionChip(
                label: const Text('Tudo ligado'),
                onPressed: () => controller.applyPreset(SchedulePreset.allOn),
              ),
              ActionChip(
                label: const Text('Tudo desligado'),
                onPressed: () =>
                    controller.applyPreset(SchedulePreset.allOff),
              ),
              ActionChip(
                label: const Text('Copiar para todos os canais'),
                onPressed: controller.copyCurveToAll,
              ),
            ],
          ),
          ),
        ),

        if (uploading)
          Padding(
            padding: const EdgeInsets.all(12),
            child: LinearProgressIndicator(value: controller.uploadProgress),
          ),
        if (message != null && !uploading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(message),
          ),

        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.upload),
                label: const Text('Enviar para a controladora'),
                onPressed: controller.connected && !uploading
                    ? controller.uploadSchedule
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
