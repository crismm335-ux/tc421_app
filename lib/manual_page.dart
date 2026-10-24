import 'package:flutter/material.dart';

import 'controller.dart';

const List<Color> channelColors = [
  Colors.blue,
  Colors.red,
  Colors.green,
  Colors.orange,
  Colors.purple,
];

class ManualPage extends StatelessWidget {
  const ManualPage({super.key, required this.controller});

  final Tc421Controller controller;

  @override
  Widget build(BuildContext context) {
    final enabled = controller.connected;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Controle ao vivo'),
          subtitle: const Text(
              'Experimental: os sliders mudam a luz na hora. Ao desligar, a controladora volta ao cronograma.'),
          value: controller.liveActive,
          onChanged: enabled ? controller.setLiveActive : null,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < controller.live.length; i++)
          Row(
            children: [
              SizedBox(width: 72, child: Text('Canal ${i + 1}')),
              Expanded(
                child: Slider(
                  value: controller.live[i].toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  activeColor: channelColors[i],
                  onChanged: enabled
                      ? (v) => controller.setLive(i, v.round())
                      : null,
                ),
              ),
              SizedBox(
                width: 48,
                child: Text('${controller.live[i]}%',
                    textAlign: TextAlign.end),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: enabled ? () => controller.setAllLive(0) : null,
                child: const Text('Apagar tudo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: enabled ? () => controller.setAllLive(100) : null,
                child: const Text('Tudo a 100%'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
