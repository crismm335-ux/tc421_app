import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aqua.dart';
import 'controller.dart';
import 'curve.dart';

/// Aba "Perfis": curvas prontas e cópia do programa em JSON.
class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key, required this.controller});

  final Tc421Controller controller;

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
        AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Perfis de iluminação'),
              const Text(
                'Aplicar um perfil substitui as curvas atuais dos cinco canais. Depois é só ajustar na Programação e enviar para a controladora.',
                style: TextStyle(color: Aqua.muted),
              ),
              const SizedBox(height: 12),
              for (final name in profilePeaks.keys)
                _ProfileCard(
                  name: name,
                  current: controller.profileName == name,
                  onTap: () {
                    controller.applyProfile(name);
                    _toast(context, 'Perfil $name aplicado.');
                  },
                ),
            ],
          ),
        ),
        AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Copiar e colar o programa'),
              const Text(
                'Exportar copia o programa em JSON para a área de transferência. Para importar, copie um JSON (do Aqua Light ou deste app) e toque em Importar.',
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
                  OutlinedButton.icon(
                    icon: const Icon(Icons.paste, size: 18),
                    label: const Text('Importar JSON'),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      final error = controller.importJson(data?.text ?? '');
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
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.current,
    required this.onTap,
  });

  final String name;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border:
                Border.all(color: current ? Aqua.cyan : const Color(0xFF14507C)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF08294B), Color(0xFF03172A)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Aqua.text)),
              const SizedBox(height: 4),
              const Text('Curvas para cinco canais',
                  style: TextStyle(color: Aqua.muted)),
              const SizedBox(height: 4),
              Text(current ? 'Perfil atual' : 'Aplicar perfil',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF8FB5D5))),
            ],
          ),
        ),
      ),
    );
  }
}
