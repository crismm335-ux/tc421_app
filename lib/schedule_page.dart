import 'package:flutter/material.dart';

import 'controller.dart';
import 'manual_page.dart' show channelColors;

String _timeLabel(int index) {
  final h = (index ~/ 2).toString().padLeft(2, '0');
  return '$h:${index.isEven ? '00' : '30'}';
}

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key, required this.controller});

  final Tc421Controller controller;

  @override
  Widget build(BuildContext context) {
    final uploading = controller.uploadProgress != null;
    final message = controller.uploadMessage;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
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
        Expanded(
          child: ListView.builder(
            itemCount: controller.schedule.length,
            itemBuilder: (context, i) => _PointRow(
              index: i,
              values: controller.schedule[i],
              onTap: () => _editPoint(context, i),
            ),
          ),
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

  void _editPoint(BuildContext context, int index) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_timeLabel(index),
                  style: Theme.of(context).textTheme.titleLarge),
              for (var c = 0; c < controller.schedule[index].length; c++)
                Row(
                  children: [
                    SizedBox(width: 72, child: Text('Canal ${c + 1}')),
                    Expanded(
                      child: Slider(
                        value: controller.schedule[index][c].toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 100,
                        activeColor: channelColors[c],
                        onChanged: (v) =>
                            controller.setPoint(index, c, v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text('${controller.schedule[index][c]}%',
                          textAlign: TextAlign.end),
                    ),
                  ],
                ),
              TextButton(
                onPressed: () => controller.copyPointToAll(index),
                child: const Text('Copiar para todos os horários'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.index,
    required this.values,
    required this.onTap,
  });

  final int index;
  final List<int> values;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 56, child: Text(_timeLabel(index))),
            for (var c = 0; c < values.length; c++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: values[c] / 100,
                      minHeight: 12,
                      color: channelColors[c],
                      backgroundColor: channelColors[c].withAlpha(38),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
