import 'package:flutter/material.dart';

import 'aqua.dart';
import 'aquarium.dart';

/// Aba "Equipamentos": tomadas, sensores e reposição do aquário.
class EquipmentPage extends StatelessWidget {
  const EquipmentPage({super.key, required this.aquarium});

  final AquariumController aquarium;

  @override
  Widget build(BuildContext context) {
    final a = aquarium;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Conexão
        AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(a.connected ? Icons.wifi : Icons.wifi_off,
                      color: a.connected ? Aqua.cyan : Aqua.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(a.status,
                        style: const TextStyle(color: Aqua.text)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings_ethernet, size: 18),
                    label: const Text('IP do aquário'),
                    onPressed: () => _askIp(context),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Atualizar'),
                    onPressed: a.ip.isEmpty ? null : a.refresh,
                  ),
                ],
              ),
            ],
          ),
        ),

        if (a.connected) ...[
          if (a.alarms.isNotEmpty)
            AquaPanel(
              color: const Color(0xFF3A1B12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.warning_amber, color: Color(0xFFFFB347)),
                    SizedBox(width: 8),
                    Text('Alertas',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: Aqua.text)),
                  ]),
                  const SizedBox(height: 6),
                  for (final alarm in a.alarms)
                    Text('• $alarm', style: const TextStyle(color: Aqua.text)),
                  if (a.atoFault)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: a.resetAto,
                        child: const Text('Liberar a reposição'),
                      ),
                    ),
                ],
              ),
            ),

          // Sensores
          Row(
            children: [
              _SensorCard('Temperatura', a.temp, '°C', 1,
                  warn: a.temp == null),
              const SizedBox(width: 8),
              _SensorCard('pH', a.ph, '', 2,
                  note: a.adsOk ? (a.phCal ? null : 'calibrar') : 'sem ADS'),
              const SizedBox(width: 8),
              _SensorCard('Salinidade', a.salinity, 'ppt', 1,
                  note: a.adsOk ? (a.ecCal ? null : 'calibrar') : 'sem ADS'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.thermostat, size: 18),
                label: const Text('Termostato'),
                onPressed: () => _thermoDialog(context),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('Calibrar sondas'),
                onPressed: () => _calibrationDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tomadas
          AquaPanel(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Tomadas'),
                if (!a.timeOk)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'A controladora ainda não obteve a hora: horários e dose diária ficam parados.',
                      style: TextStyle(color: Color(0xFFFFB347)),
                    ),
                  ),
                for (final o in a.outlets) _OutletTile(aquarium: a, outlet: o),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _askIp(BuildContext context) async {
    final field = TextEditingController(text: aquarium.ip);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IP da controladora do aquário'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'O IP aparece no Monitor Serial do Arduino ao ligar o ESP32, e também na lista de aparelhos do roteador.'),
            const SizedBox(height: 12),
            TextField(
              controller: field,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: '192.168.0.60',
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
    if (result != null) await aquarium.setIp(result);
  }

  Future<void> _thermoDialog(BuildContext context) async {
    final t = aquarium.thermo;
    final fields = <String, TextEditingController>{
      'hon': TextEditingController(text: '${t['heaterOn'] ?? 25.0}'),
      'hoff': TextEditingController(text: '${t['heaterOff'] ?? 25.4}'),
      'con': TextEditingController(text: '${t['chillerOn'] ?? 26.5}'),
      'coff': TextEditingController(text: '${t['chillerOff'] ?? 26.0}'),
      'alo': TextEditingController(text: '${t['alarmLo'] ?? 23.0}'),
      'ahi': TextEditingController(text: '${t['alarmHi'] ?? 28.0}'),
    };
    const labels = {
      'hon': 'Aquecedor liga abaixo de (°C)',
      'hoff': 'Aquecedor desliga em (°C)',
      'con': 'Resfriamento liga acima de (°C)',
      'coff': 'Resfriamento desliga em (°C)',
      'alo': 'Alerta de temperatura baixa (°C)',
      'ahi': 'Alerta alto e corte do aquecedor (°C)',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Termostato'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: e.value,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: labels[e.key],
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final values = <String, double>{};
    for (final e in fields.entries) {
      final v = double.tryParse(e.value.text.replaceAll(',', '.'));
      if (v == null) return;
      values[e.key] = v;
    }
    await aquarium.setThermo(values);
  }

  Future<void> _calibrationDialog(BuildContext context) async {
    final ref = TextEditingController(text: '53.0');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calibrar sondas'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'pH: mergulhe a sonda na solução tampão, espere a leitura estabilizar e toque no botão correspondente.'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => aquarium.calibratePh(7),
                    child: const Text('Calibrar pH 7'),
                  ),
                  OutlinedButton(
                    onPressed: () => aquarium.calibratePh(4),
                    child: const Text('Calibrar pH 4'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                  'Salinidade: sonda na solução de referência. Informe a condutividade dela em mS/cm (água do mar a 35 ppt é cerca de 53).'),
              const SizedBox(height: 8),
              TextField(
                controller: ref,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Referência (mS/cm)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  final v = double.tryParse(ref.text.replaceAll(',', '.'));
                  if (v != null) aquarium.calibrateEc(v);
                },
                child: const Text('Calibrar salinidade'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard(this.label, this.value, this.unit, this.decimals,
      {this.note, this.warn = false});

  final String label;
  final double? value;
  final String unit;
  final int decimals;
  final String? note;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '--' : value!.toStringAsFixed(decimals);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Aqua.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: warn ? const Color(0xFFFFB347) : Aqua.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Aqua.muted, fontSize: 12)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('$text $unit',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Aqua.text)),
            ),
            if (note != null)
              Text(note!,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFFFB347))),
          ],
        ),
      ),
    );
  }
}

class _OutletTile extends StatelessWidget {
  const _OutletTile({required this.aquarium, required this.outlet});

  final AquariumController aquarium;
  final OutletState outlet;

  String get _subtitle {
    final o = outlet;
    return switch (o.mode) {
      OutletMode.schedule =>
        'Horário · ${minuteLabel(o.onMin)} às ${minuteLabel(o.offMin)}',
      OutletMode.dose =>
        'Dose diária · ${minuteLabel(o.onMin)}, ${o.doseSec} s',
      _ => modeName(o.mode),
    };
  }

  @override
  Widget build(BuildContext context) {
    final o = outlet;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: o.on ? Aqua.cyan : const Color(0xFF2A4258),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(o.name, style: const TextStyle(color: Aqua.text)),
      subtitle: Text(_subtitle, style: const TextStyle(color: Aqua.muted)),
      trailing: Text(
        o.on ? 'LIGADA' : 'DESLIGADA',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1,
          color: o.on ? Aqua.cyan : Aqua.muted,
        ),
      ),
      onTap: () => _edit(context),
    );
  }

  Future<void> _edit(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Aqua.panel,
      builder: (context) => _OutletSheet(aquarium: aquarium, outlet: outlet),
    );
  }
}

class _OutletSheet extends StatefulWidget {
  const _OutletSheet({required this.aquarium, required this.outlet});

  final AquariumController aquarium;
  final OutletState outlet;

  @override
  State<_OutletSheet> createState() => _OutletSheetState();
}

class _OutletSheetState extends State<_OutletSheet> {
  late int mode = widget.outlet.mode;
  late int onMin = widget.outlet.onMin;
  late int offMin = widget.outlet.offMin;
  late final TextEditingController sec =
      TextEditingController(text: '${widget.outlet.doseSec}');

  Future<int?> _pick(int initial) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.outlet;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o.name,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Aqua.text)),
            const SizedBox(height: 14),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final m in o.modes)
                  ButtonSegment(value: m, label: Text(modeName(m))),
              ],
              selected: {mode},
              onSelectionChanged: (s) => setState(() => mode = s.first),
            ),
            const SizedBox(height: 14),
            if (mode == OutletMode.schedule)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final v = await _pick(onMin);
                        if (v != null) setState(() => onMin = v);
                      },
                      child: Text('Liga ${minuteLabel(onMin)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final v = await _pick(offMin);
                        if (v != null) setState(() => offMin = v);
                      },
                      child: Text('Desliga ${minuteLabel(offMin)}'),
                    ),
                  ),
                ],
              ),
            if (mode == OutletMode.dose) ...[
              OutlinedButton(
                onPressed: () async {
                  final v = await _pick(onMin);
                  if (v != null) setState(() => onMin = v);
                },
                child: Text('Horário da dose ${minuteLabel(onMin)}'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sec,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duração da dose (segundos)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (o.id == 4 && mode == OutletMode.on)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Mesmo ligado à mão, o aquecedor desliga se a temperatura passar do limite ou se o sensor falhar.',
                  style: TextStyle(color: Aqua.muted),
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  await widget.aquarium.setOutlet(
                    o.id,
                    mode,
                    onMin: onMin,
                    offMin: offMin,
                    doseSec: int.tryParse(sec.text),
                  );
                  nav.pop();
                },
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
