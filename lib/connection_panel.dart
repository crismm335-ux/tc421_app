import 'package:flutter/material.dart';

import 'aqua.dart';
import 'controller.dart';

/// Conexão com a controladora: status, hora, IP manual e nova busca.
class ConnectionPanel extends StatelessWidget {
  const ConnectionPanel({super.key, required this.controller});

  final Tc421Controller controller;

  @override
  Widget build(BuildContext context) {
    return AquaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(controller.connected ? Icons.wifi : Icons.wifi_off,
                  color: controller.connected ? Aqua.cyan : Aqua.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(controller.status,
                    style: const TextStyle(color: Aqua.text)),
              ),
              if (controller.searching)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (controller.connected)
                OutlinedButton.icon(
                  icon: const Icon(Icons.access_time, size: 18),
                  label: const Text('Sincronizar hora'),
                  onPressed: controller.syncTime,
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings_ethernet, size: 18),
                label: const Text('IP da controladora'),
                onPressed: () => _askIp(context),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Procurar novamente'),
                onPressed: controller.searching ? null : controller.connect,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.wifi_password, size: 18),
                label: const Text('Configurar Wi-Fi'),
                onPressed: () => _wifiInfo(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _wifiInfo(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conectar a controladora ao seu Wi-Fi'),
        content: const Text(
            'Ainda não dá para fazer isso por aqui: o comando que a TC421 usa '
            'para receber o nome e a senha da rede não é documentado.\n\n'
            'Configure uma vez pelo app oficial dela (Smart Timer). Depois '
            'disso, este app encontra a controladora sozinho na sua rede, ou '
            'você informa o IP dela.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Future<void> _askIp(BuildContext context) async {
    final field = TextEditingController(text: controller.manualIp ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IP da controladora'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Veja o IP no painel do seu roteador (lista de aparelhos conectados). Deixe vazio para procurar por broadcast.'),
            const SizedBox(height: 12),
            TextField(
              controller: field,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '192.168.0.50',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
    if (result != null) await controller.setManualIp(result);
  }
}
