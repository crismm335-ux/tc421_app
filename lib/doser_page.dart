import 'package:flutter/material.dart';

import 'aqua.dart';
import 'aquarium.dart';

/// Cor de cada canal da dosadora.
const List<Color> doserColors = [
  Color(0xFF3FD2FF),
  Color(0xFFFFC53D),
  Color(0xFFB06BFF),
  Color(0xFF2EE6B0),
];

/// Nomes comuns para os recipientes.
const List<String> doserSuggestions = [
  'Alcalinidade (KH)',
  'Cálcio',
  'Magnésio',
  'Elementos traço',
  'Iodo',
  'Potássio',
  'Estrôncio',
  'Aminoácidos',
];

String fmtMl(double v, [int dec = 1]) =>
    v.toStringAsFixed(dec).replaceAll('.', ',');

String hhmm(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

/// Aba "Dosadora": 4 bombas dosadoras controladas pelo ESP32.
class DoserPage extends StatelessWidget {
  const DoserPage({super.key, required this.aquarium, required this.onGo});

  final AquariumController aquarium;

  /// 4 abre Equipamentos (onde se informa o IP do ESP32).
  final void Function(int code) onGo;

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final a = aquarium;
    if (!a.connected) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        children: [
          AquaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Dosadora sem conexão'),
                const Text(
                  'A dosadora é comandada pelo ESP32 do aquário. Conecte o ESP32 para ver e ajustar os 4 canais.',
                  style: TextStyle(color: Aqua.muted),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.wifi, size: 18),
                  label: const Text('Conectar o ESP32'),
                  onPressed: () => onGo(4),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (!a.hasDoser) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        children: const [
          AquaPanel(
            child: Text(
              'O programa gravado no ESP32 ainda não tem a dosadora de 4 canais. Grave o programa novo da pasta firmware (veja o LEIAME).',
              style: TextStyle(color: Aqua.text),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      children: [
        _StatusCard(aquarium: a),
        for (var c = 0; c < a.doser.length; c++)
          _ChannelCard(
            aquarium: a,
            index: c,
            onToast: (t) => _toast(context, t),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'As bombas funcionam uma de cada vez e ficam paradas durante a TPA. Calibre cada canal antes de usar.',
            style: TextStyle(fontSize: 12, color: Aqua.muted),
          ),
        ),
      ],
    );
  }
}

/// Situação geral: dosando agora ou próxima dose.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.aquarium});

  final AquariumController aquarium;

  @override
  Widget build(BuildContext context) {
    final a = aquarium;
    final running = a.doserRunning;
    if (running >= 0 && running < a.doser.length) {
      final ch = a.doser[running];
      final color = doserColors[running];
      final total = a.doserTotal <= 0 ? 1 : a.doserTotal;
      return AquaPanel(
        borderColor: color,
        glow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AquaOrb(icon: Icons.water_drop, color: color, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.doserCalib ? 'Calibrando' : 'Dosando agora',
                          style: const TextStyle(
                              fontSize: 13, color: Aqua.muted)),
                      Text(ch.name,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Parar'),
                  onPressed: a.stopDoser,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (a.doserElapsed / total).clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                color: color,
                backgroundColor: Aqua.track,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              a.doserCalib
                  ? '${a.doserElapsed} de ${a.doserTotal} s · deixe a mangueira dentro de um copo de medida'
                  : '${a.doserElapsed} de ${a.doserTotal} s',
              style: const TextStyle(fontSize: 12, color: Aqua.muted),
            ),
          ],
        ),
      );
    }

    // Próxima dose entre todos os canais
    int? bestMin;
    int bestCh = -1;
    for (var c = 0; c < a.doser.length; c++) {
      final ch = a.doser[c];
      if (!ch.enabled || ch.next < 0) continue;
      if (bestMin == null || ch.next < bestMin) {
        bestMin = ch.next;
        bestCh = c;
      }
    }
    final anyOn = a.doser.any((c) => c.enabled);
    return AquaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AquaOrb(
                  icon: Icons.schedule,
                  color: bestCh >= 0 ? doserColors[bestCh] : Aqua.muted,
                  size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Próxima dose',
                        style: TextStyle(fontSize: 13, color: Aqua.muted)),
                    Text(
                      bestCh >= 0
                          ? '${hhmm(bestMin!)} · ${a.doser[bestCh].name} · ${fmtMl(a.doser[bestCh].perDose)} ml'
                          : (anyOn
                              ? 'Nenhuma até o fim do dia'
                              : 'Nenhum canal ligado'),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Aqua.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!a.timeOk)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'O ESP32 ainda não tem a hora certa: a agenda fica parada até ele obter a hora pela internet.',
                style: TextStyle(fontSize: 12, color: Aqua.amber),
              ),
            ),
          if (a.doserMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(a.doserMsg,
                  style: const TextStyle(fontSize: 12, color: Aqua.amber)),
            ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.aquarium,
    required this.index,
    required this.onToast,
  });

  final AquariumController aquarium;
  final int index;
  final ValueChanged<String> onToast;

  @override
  Widget build(BuildContext context) {
    final a = aquarium;
    final ch = a.doser[index];
    final color = doserColors[index];
    final busy = a.doserRunning >= 0;
    final double todayPart =
        ch.mlDay <= 0 ? 0.0 : (ch.today / ch.mlDay).clamp(0.0, 1.0).toDouble();
    final double leftPart = ch.capacity <= 0
        ? 0.0
        : (ch.left / ch.capacity).clamp(0.0, 1.0).toDouble();
    final days = ch.daysLeft;
    final low = ch.empty || (days != null && days < 3 && ch.enabled);
    return AquaPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Opacity(
        opacity: ch.enabled ? 1 : 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fade(color, 0.14),
                    border: Border.all(color: color, width: 1.6),
                  ),
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Aqua.text)),
                      Text(
                        ch.enabled
                            ? '${fmtMl(ch.perDose)} ml × ${ch.doses} · ${ch.start == ch.end ? 'dia todo' : '${hhmm(ch.start)}–${hhmm(ch.end)}'}'
                            : 'Desligado',
                        style: const TextStyle(fontSize: 12, color: Aqua.muted),
                      ),
                    ],
                  ),
                ),
                AquaSwitch(
                  value: ch.enabled,
                  onChanged: (v) => a.setDoser(index, enabled: v),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Hoje
            _BarRow(
              label: 'Hoje',
              value: '${fmtMl(ch.today)} de ${fmtMl(ch.mlDay)} ml',
              part: todayPart,
              color: color,
              trailing: ch.enabled && ch.next >= 0 ? 'próxima ${hhmm(ch.next)}' : null,
            ),
            const SizedBox(height: 10),

            // Recipiente
            _BarRow(
              label: 'Recipiente',
              value: '${fmtMl(ch.left, 0)} de ${fmtMl(ch.capacity, 0)} ml',
              part: leftPart,
              color: low ? Aqua.amber : fade(color, 0.7),
              trailing: ch.empty
                  ? 'vazio'
                  : (days == null ? null : (days > 365 ? '+1 ano' : '~$days dias')),
              warn: low,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _SmallButton(
                    icon: Icons.tune,
                    label: 'Ajustar',
                    onTap: () => _settings(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallButton(
                    icon: Icons.water_drop_outlined,
                    label: 'Dosar',
                    onTap: busy ? null : () => _doseNow(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SmallButton(
                    icon: Icons.local_drink_outlined,
                    label: 'Encher',
                    onTap: () => _refill(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refill(BuildContext context) async {
    final ch = aquarium.doser[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Aqua.panel,
        title: Text('Encheu o recipiente de ${ch.name}?'),
        content: Text(
            'O app volta a contar ${fmtMl(ch.capacity, 0)} ml. Se o recipiente tem outro tamanho, mude em Ajustar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Recipiente cheio')),
        ],
      ),
    );
    if (ok == true) {
      await aquarium.refillDoser(index);
      onToast('Recipiente de ${ch.name} marcado como cheio.');
    }
  }

  Future<void> _doseNow(BuildContext context) async {
    final ch = aquarium.doser[index];
    var ml = ch.perDose > 0 ? double.parse(ch.perDose.toStringAsFixed(1)) : 1.0;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Aqua.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dose avulsa · ${ch.name}',
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Aqua.text)),
                const SizedBox(height: 4),
                const Text('Não muda a agenda. Conta no recipiente e no total de hoje.',
                    style: TextStyle(color: Aqua.muted)),
                const SizedBox(height: 16),
                _Stepper(
                  label: 'Quantidade',
                  value: '${fmtMl(ml)} ml',
                  onMinus: ml > 0.5 ? () => setSheet(() => ml = (ml - 0.5).clamp(0.5, 100.0).toDouble()) : null,
                  onPlus: ml < 100 ? () => setSheet(() => ml = (ml + 0.5).clamp(0.5, 100.0).toDouble()) : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.water_drop),
                    label: Text('Dosar ${fmtMl(ml)} ml agora'),
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true) {
      await aquarium.doseNow(index, ml);
      onToast('Dose de ${fmtMl(ml)} ml de ${ch.name} na fila.');
    }
  }

  Future<void> _settings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Aqua.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SettingsSheet(
        aquarium: aquarium,
        index: index,
        onToast: onToast,
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.aquarium,
    required this.index,
    required this.onToast,
  });

  final AquariumController aquarium;
  final int index;
  final ValueChanged<String> onToast;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final DoserChannel ch = widget.aquarium.doser[widget.index];
  late final TextEditingController name = TextEditingController(text: ch.name);
  late final TextEditingController cap =
      TextEditingController(text: ch.capacity.toStringAsFixed(0));
  late final TextEditingController measured = TextEditingController();
  late double mlDay = ch.mlDay;
  late int doses = ch.doses;
  late int start = ch.start;
  late int end = ch.end;
  late bool allDay = ch.start == ch.end;
  bool calibrating = false;

  @override
  void dispose() {
    name.dispose();
    cap.dispose();
    measured.dispose();
    super.dispose();
  }

  InputDecoration _field(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Aqua.muted),
        filled: true,
        fillColor: Aqua.field,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Aqua.buttonLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Aqua.cyan),
        ),
      );

  Future<void> _pick(bool isStart) async {
    final initial = isStart ? start : end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    if (t == null) return;
    setState(() {
      if (isStart) {
        start = t.hour * 60 + t.minute;
      } else {
        end = t.hour * 60 + t.minute;
      }
    });
  }

  Future<void> _save() async {
    final capValue = double.tryParse(cap.text.replaceAll(',', '.'));
    await widget.aquarium.setDoser(
      widget.index,
      name: name.text.trim().isEmpty ? null : name.text.trim(),
      mlDay: mlDay,
      doses: doses,
      start: start,
      end: allDay ? start : (end == start ? (start + 60) % 1440 : end),
      capacity: capValue,
    );
    if (mounted) Navigator.pop(context);
    widget.onToast('Canal ${widget.index + 1} salvo.');
  }

  @override
  Widget build(BuildContext context) {
    final color = doserColors[widget.index];
    final perDose = doses == 0 ? 0.0 : mlDay / doses;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Canal ${widget.index + 1}',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 14),
            TextField(
              controller: name,
              maxLength: 24,
              style: const TextStyle(color: Aqua.text),
              decoration: _field('O que este canal doseia').copyWith(counterText: ''),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in doserSuggestions)
                  ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => name.text = s),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _Stepper(
              label: 'Por dia',
              value: '${fmtMl(mlDay)} ml',
              onMinus: mlDay > 0 ? () => setState(() => mlDay = (mlDay - 0.5).clamp(0.0, 500.0).toDouble()) : null,
              onPlus: mlDay < 500 ? () => setState(() => mlDay = (mlDay + 0.5).clamp(0.0, 500.0).toDouble()) : null,
            ),
            const SizedBox(height: 10),
            _Stepper(
              label: 'Doses por dia',
              value: '$doses',
              onMinus: doses > 1 ? () => setState(() => doses--) : null,
              onPlus: doses < 24 ? () => setState(() => doses++) : null,
            ),
            const SizedBox(height: 6),
            Text('${fmtMl(perDose, 2)} ml em cada dose',
                style: TextStyle(fontSize: 13, color: color)),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text('Espalhar no dia todo',
                      style: TextStyle(color: Aqua.text)),
                ),
                AquaSwitch(
                  value: allDay,
                  onChanged: (v) => setState(() => allDay = v),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(true),
                    child: Text(allDay ? 'Começa ${hhmm(start)}' : 'Primeira ${hhmm(start)}'),
                  ),
                ),
                if (!allDay) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(false),
                      child: Text('Última ${hhmm(end)}'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: cap,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Aqua.text),
              decoration: _field('Tamanho do recipiente (ml)'),
            ),
            const SizedBox(height: 18),

            // Calibração
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Aqua.field,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Aqua.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calibração · ${fmtMl(ch.rate)} ml por minuto',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: Aqua.text)),
                  const SizedBox(height: 4),
                  const Text(
                    'Coloque a mangueira num copo de medida e toque em Ligar 1 minuto. Depois digite quanto saiu.',
                    style: TextStyle(fontSize: 12, color: Aqua.muted),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.timer_outlined, size: 18),
                          label: const Text('Ligar 1 minuto'),
                          onPressed: widget.aquarium.doserRunning >= 0
                              ? null
                              : () async {
                                  await widget.aquarium
                                      .calibrateDoser(widget.index);
                                  setState(() => calibrating = true);
                                },
                        ),
                      ),
                    ],
                  ),
                  if (calibrating) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: measured,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: const TextStyle(color: Aqua.text),
                            decoration: _field('Quanto saiu (ml)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: () async {
                            final v = double.tryParse(
                                measured.text.replaceAll(',', '.'));
                            if (v == null || v <= 0) return;
                            await widget.aquarium
                                .setDoser(widget.index, rate: v);
                            setState(() => calibrating = false);
                            widget.onToast(
                                'Canal ${widget.index + 1} calibrado: ${fmtMl(v)} ml/min.');
                          },
                          child: const Text('Salvar'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Salvar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.part,
    required this.color,
    this.trailing,
    this.warn = false,
  });

  final String label;
  final String value;
  final double part;
  final Color color;
  final String? trailing;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Aqua.muted)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Aqua.text)),
            ),
            if (trailing != null)
              Text(trailing!,
                  style: TextStyle(
                      fontSize: 12, color: warn ? Aqua.amber : Aqua.muted)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: part,
            minHeight: 7,
            color: color,
            backgroundColor: Aqua.track,
          ),
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onPressed: onTap,
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Aqua.text))),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: onMinus,
        ),
        SizedBox(
          width: 76,
          child: Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Aqua.text)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onPlus,
        ),
      ],
    );
  }
}
