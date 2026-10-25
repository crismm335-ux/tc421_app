import 'package:flutter/material.dart';

import 'aqua.dart';
import 'controller.dart';

/// Canais do aquário marinho (não há canal vermelho).
const List<Color> channelColors = [
  Color(0xFF6577FF), // Royal Blue
  Color(0xFF38A9FF), // Blue
  Color(0xFF22E3EE), // Ciano
  Color(0xFFF4F8FF), // Branco
  Color(0xFFB97CFF), // Violeta
];

const List<String> channelNames = [
  'Royal Blue',
  'Blue',
  'Ciano',
  'Branco',
  'Violeta',
];

/// Aba "Canais": controle ao vivo, um slider por canal.
class ManualPage extends StatelessWidget {
  const ManualPage({super.key, required this.controller});

  final Tc421Controller controller;

  @override
  Widget build(BuildContext context) {
    final enabled = controller.connected;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Controle dos canais'),
              const Text(
                'Ajuste cada canal na hora. É experimental: ao desligar, a controladora volta ao cronograma.',
                style: TextStyle(color: Aqua.muted),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Controle ao vivo'),
                value: controller.liveActive,
                onChanged: enabled ? controller.setLiveActive : null,
              ),
            ],
          ),
        ),
        for (var i = 0; i < controller.live.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            decoration: BoxDecoration(
              color: Aqua.field,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Aqua.line),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: channelColors[i],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: channelColors[i], blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('CH${i + 1} · ${channelNames[i]}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, color: Aqua.text)),
                    ),
                    Text('${controller.live[i]}%',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: channelColors[i])),
                  ],
                ),
                Slider(
                  value: controller.live[i].toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  activeColor: channelColors[i],
                  onChanged: enabled
                      ? (v) => controller.setLive(i, v.round())
                      : null,
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
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
