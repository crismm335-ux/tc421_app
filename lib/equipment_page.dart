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
              SensorCard('Temperatura', a.temp, '°C', 1,
                  warn: a.temp == null),
              const SizedBox(width: 8),
              SensorCard('pH', a.ph, '', 2,
                  note: a.adsOk ? (a.phCal ? null : 'calibrar') : 'sem ADS'),
              const SizedBox(width: 8),
              SensorCard('Salinidade', a.salinity, 'ppt', 1,
                  note: a.adsOk ? (a.ecCal ? null : 'calibrar') : 'sem ADS'),
            ],
          ),
          const SizedBox(height: 12),
          AquaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Temperatura'),
                Text(
                  a.temp == null
                      ? 'Sensor sem leitura.'
                      : 'Agora: ${a.temp!.toStringAsFixed(1)} °C',
                  style: const TextStyle(color: Aqua.muted),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.thermostat, size: 18),
                  label: const Text('Controle de temperatura'),
                  onPressed: () => _thermoDialog(context),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('Calibrar sondas'),
            onPressed: () => _calibrationDialog(context),
          ),
          const SizedBox(height: 12),

          _TpaPanel(aquarium: a),

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
        title: const Text('Controle de temperatura'),
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

class SensorCard extends StatelessWidget {
  const SensorCard(this.label, this.value, this.unit, this.decimals,
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

/// Troca parcial de água: retira do sump e repõe água pronta.
class _TpaPanel extends StatelessWidget {
  const _TpaPanel({required this.aquarium});

  final AquariumController aquarium;

  String get _phase => switch (aquarium.tpaState) {
        1 => 'Retirando água do sump',
        2 => 'Aguardando',
        3 => 'Repondo água pronta',
        _ => 'Parada',
      };

  @override
  Widget build(BuildContext context) {
    final a = aquarium;
    final running = a.tpaState != 0;
    final progress = (running && a.tpaTotal > 0)
        ? (a.tpaElapsed / a.tpaTotal).clamp(0.0, 1.0)
        : (a.tpaState == 2 ? 1.0 : 0.0);
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: Aqua.muted);
    return AquaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Troca parcial de água (TPA)'),
          Text(
            'Retira ${a.tpaLiters.toStringAsFixed(1)} L do sump e repõe a mesma quantidade com a água pronta do reservatório.',
            style: const TextStyle(color: Aqua.muted),
          ),
          const SizedBox(height: 12),
          if (running) ...[
            Text(_phase,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Aqua.text)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 12),
          ] else if (a.tpaMsg.isNotEmpty) ...[
            Text(a.tpaMsg, style: const TextStyle(color: Aqua.text)),
            const SizedBox(height: 12),
          ],
          if (a.tpaMinLevel && !running)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('O sump está no nível mínimo: não dá para retirar água agora.',
                  style: muted?.copyWith(color: const Color(0xFFFFB347))),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!running)
                FilledButton.icon(
                  icon: const Icon(Icons.water_drop_outlined, size: 18),
                  label: const Text('Iniciar TPA'),
                  onPressed: a.tpaMinLevel ? null : () => _confirm(context),
                )
              else
                FilledButton.icon(
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Parar TPA'),
                  onPressed: a.tpaStop,
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Litros e vazões'),
                onPressed: running ? null : () => _config(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Vazões: retirada ${a.tpaDrainLpm.toStringAsFixed(1)} L/min, reposição ${a.tpaFillLpm.toStringAsFixed(1)} L/min. Durante a TPA a reposição automática e o skimmer ficam desligados.',
            style: muted,
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final a = aquarium;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar a troca de água?'),
        content: Text(
            'Vou retirar ${a.tpaLiters.toStringAsFixed(1)} L do sump e repor a mesma quantidade.\n\n'
            'Confira antes: o reservatório tem água pronta suficiente, com a mesma salinidade e temperatura do aquário, e o destino da água retirada está livre.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
    if (ok == true) await a.tpaStart();
  }

  Future<void> _config(BuildContext context) async {
    final a = aquarium;
    final liters = TextEditingController(text: a.tpaLiters.toString());
    final drain = TextEditingController(text: a.tpaDrainLpm.toString());
    final fill = TextEditingController(text: a.tpaFillLpm.toString());
    Widget field(String label, TextEditingController c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder()),
          ),
        );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Litros e vazões'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field('Litros a trocar', liters),
              field('Vazão da bomba de retirada (L/min)', drain),
              field('Vazão da bomba de reposição (L/min)', fill),
              const Text(
                  'Meça a vazão real de cada bomba com um balde e um cronômetro. A quantidade é calculada pelo tempo.'),
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
    double? v(TextEditingController c) =>
        double.tryParse(c.text.replaceAll(',', '.'));
    final l = v(liters), d = v(drain), f = v(fill);
    if (l == null || d == null || f == null) return;
    await a.setTpaConfig(l, d, f);
  }
}
