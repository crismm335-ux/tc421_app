import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'aqua.dart';
import 'remote.dart';

/// Configuração do acesso pela internet (tela Conexão).
class RemotePanel extends StatefulWidget {
  const RemotePanel({super.key, required this.remote});

  final RemoteLink remote;

  @override
  State<RemotePanel> createState() => _RemotePanelState();
}

class _RemotePanelState extends State<RemotePanel> {
  late final TextEditingController host =
      TextEditingController(text: widget.remote.host);
  late final TextEditingController port =
      TextEditingController(text: '${widget.remote.port}');
  late final TextEditingController user =
      TextEditingController(text: widget.remote.user);
  late final TextEditingController pass =
      TextEditingController(text: widget.remote.password);
  late final TextEditingController device =
      TextEditingController(text: widget.remote.deviceId);
  bool showPass = false;
  bool saving = false;

  @override
  void dispose() {
    host.dispose();
    port.dispose();
    user.dispose();
    pass.dispose();
    device.dispose();
    super.dispose();
  }

  InputDecoration _field(String label, {String? hint, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Aqua.muted),
        hintStyle: TextStyle(color: fade(Aqua.muted, 0.6)),
        filled: true,
        fillColor: Aqua.field,
        isDense: true,
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Aqua.buttonLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Aqua.cyan),
        ),
      );

  Future<void> _save() async {
    setState(() => saving = true);
    FocusScope.of(context).unfocus();
    await widget.remote.save(
      host: host.text,
      port: int.tryParse(port.text.trim()) ?? 8883,
      user: user.text,
      password: pass.text,
      deviceId: device.text,
    );
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.remote;
    return ListenableBuilder(
      listenable: r,
      builder: (context, _) {
        final Color dot = r.ready
            ? Aqua.green
            : (r.connected ? Aqua.amber : Aqua.muted);
        final String line = !r.configured
            ? 'Desligado. Preencha os dados abaixo para usar fora de casa.'
            : (r.ready
                ? 'Pronto: dá para usar de qualquer lugar.'
                : (r.connected
                    ? 'Servidor conectado, mas o ESP32 não está online. Ele tem os mesmos dados no programa?'
                    : r.status));
        return AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Acesso pela internet'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: dot, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(line, style: const TextStyle(color: Aqua.text)),
                  ),
                  if (r.connecting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              if (r.lastStatusAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 20),
                  child: Text(
                    'Última notícia do aquário: ${_ago(r.lastStatusAt!)}',
                    style: const TextStyle(fontSize: 12, color: Aqua.muted),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                kIsWeb
                    ? 'Use os mesmos dados que estão no programa do ESP32 (MQTT_HOST, MQTT_USER, MQTT_PASS e DEVICE_ID). Na versão web tudo passa pela internet, em casa também; a porta usada é a 8884 (WebSocket), o campo Porta é ignorado.'
                    : 'Use os mesmos dados que estão no programa do ESP32 (MQTT_HOST, MQTT_USER, MQTT_PASS e DEVICE_ID). Em casa o app continua usando o Wi-Fi; fora de casa ele passa pela internet sozinho.',
                style: const TextStyle(fontSize: 12, color: Aqua.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: host,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: const TextStyle(color: Aqua.text),
                decoration: _field('Servidor',
                    hint: 'abc123.s1.eu.hivemq.cloud'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: user,
                      autocorrect: false,
                      style: const TextStyle(color: Aqua.text),
                      decoration: _field('Usuário'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: port,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Aqua.text),
                      decoration: _field('Porta'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pass,
                obscureText: !showPass,
                autocorrect: false,
                style: const TextStyle(color: Aqua.text),
                decoration: _field(
                  'Senha',
                  suffix: IconButton(
                    icon: Icon(showPass ? Icons.visibility_off : Icons.visibility,
                        color: Aqua.muted),
                    onPressed: () => setState(() => showPass = !showPass),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: device,
                autocorrect: false,
                style: const TextStyle(color: Aqua.text),
                decoration: _field('Nome do aquário (DEVICE_ID)',
                    hint: 'aquario-k7p3x9'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (r.configured)
                    TextButton(
                      onPressed: saving
                          ? null
                          : () async {
                              host.clear();
                              user.clear();
                              pass.clear();
                              device.clear();
                              await _save();
                            },
                      child: const Text('Desligar'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.cloud_outlined, size: 18),
                    label: Text(saving ? 'Conectando...' : 'Salvar e conectar'),
                    onPressed: saving ? null : _save,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _ago(DateTime t) {
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 60) return 'agora há pouco';
    if (s < 3600) return 'há ${s ~/ 60} min';
    return 'há ${s ~/ 3600} h';
  }
}
