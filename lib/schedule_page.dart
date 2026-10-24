import 'package:flutter/material.dart';

import 'controller.dart';
import 'curve_editor.dart';
import 'manual_page.dart' show channelColors;

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
          child: Row(
            children: [
              const Text('Canal'),
              const SizedBox(width: 8),
              for (var c = 0; c < channelColors.length; c++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: CircleAvatar(
                      radius: 6,
                      backgroundColor: channelColors[c],
                    ),
                    label: Text('${c + 1}'),
                    selected: controller.selectedChannel == c,
                    onSelected: (_) => controller.selectChannel(c),
                  ),
                ),
            ],
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
            ),
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
