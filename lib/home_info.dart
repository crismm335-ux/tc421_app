import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'animals_page.dart' show Animal, animalKinds, animalIcons, kindColors, kindPlural;
import 'aqua.dart';
import 'aquarium.dart';
import 'home_page.dart' show SectionLabel;
import 'tests_page.dart' show TestEntry, testParams;

/// Uma informação que pode aparecer no Início.
class InfoOption {
  const InfoOption(this.key, this.label, this.group, this.icon);
  final String key;
  final String label;
  final String group;
  final IconData icon;
}

const List<InfoOption> infoOptions = [
  InfoOption('temp', 'Temperatura', 'Sensores (ESP32)', Icons.thermostat),
  InfoOption('ph', 'pH', 'Sensores (ESP32)', Icons.water_drop_outlined),
  InfoOption('sal', 'Salinidade', 'Sensores (ESP32)', Icons.waves),
  InfoOption('alerts', 'Alertas', 'Equipamentos', Icons.warning_amber),
  InfoOption('levels', 'Níveis de água', 'Equipamentos', Icons.water),
  InfoOption('outlets', 'Tomadas', 'Equipamentos', Icons.power_outlined),
  InfoOption('tpa', 'Troca de água (TPA)', 'Equipamentos', Icons.autorenew),
  InfoOption('t_kh', 'KH', 'Último teste', Icons.science_outlined),
  InfoOption('t_ca', 'Cálcio', 'Último teste', Icons.science_outlined),
  InfoOption('t_mg', 'Magnésio', 'Último teste', Icons.science_outlined),
  InfoOption('t_no3', 'Nitrato', 'Último teste', Icons.science_outlined),
  InfoOption('t_po4', 'Fosfato', 'Último teste', Icons.science_outlined),
  InfoOption('animals', 'Animais', 'Habitantes', Icons.set_meal_outlined),
];

const List<String> defaultInfo = ['temp', 'ph', 'sal', 'alerts', 'levels', 'animals'];

/// Seção "Aquário" do Início, com as informações escolhidas.
class HomeAquariumInfo extends StatefulWidget {
  const HomeAquariumInfo(
      {super.key, required this.aquarium, required this.onGo, this.connection});

  final AquariumController aquarium;

  /// Cartão de conexão do ESP32, mostrado logo abaixo do título.
  final Widget? connection;

  /// 4 equipamentos, 7 animais, 8 testes.
  final void Function(int code) onGo;

  @override
  State<HomeAquariumInfo> createState() => _HomeAquariumInfoState();
}

class _HomeAquariumInfoState extends State<HomeAquariumInfo> {
  static const _prefsKey = 'home_info_v1';
  List<String> selected = List.of(defaultInfo);
  List<TestEntry> tests = [];
  List<Animal> animals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey);
    final t = <TestEntry>[];
    final a = <Animal>[];
    try {
      final raw = prefs.getString('water_tests_v1');
      if (raw != null) {
        t.addAll((jsonDecode(raw) as List)
            .map((e) => TestEntry.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
    try {
      final raw = prefs.getString('animals_v1');
      if (raw != null) {
        a.addAll((jsonDecode(raw) as List)
            .map((e) => Animal.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      if (saved != null) selected = saved;
      tests = t;
      animals = a;
    });
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, selected);
  }

  /// Valor mais recente de um teste e a data dele.
  (double, String)? _latestTest(String key) {
    for (final e in tests) {
      final v = e.values[key];
      if (v != null) return (v, e.date);
    }
    return null;
  }

  void _customize() {
    final groups = <String>[];
    for (final o in infoOptions) {
      if (!groups.contains(o.group)) groups.add(o.group);
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Aqua.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void toggle(String key, bool on) {
            setSheet(() {});
            setState(() {
              if (on) {
                // Mantém a ordem da lista de opções.
                selected = [
                  for (final o in infoOptions)
                    if (selected.contains(o.key) || o.key == key) o.key
                ];
              } else {
                selected = selected.where((k) => k != key).toList();
              }
            });
            _saveSelection();
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.92,
            builder: (ctx, scroll) => ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const Text('Informações no Início',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Aqua.text)),
                const SizedBox(height: 4),
                const Text('Escolha o que aparece na seção Aquário.',
                    style: TextStyle(color: Aqua.muted)),
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                    child: Text(g.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 1,
                            color: Aqua.muted,
                            fontWeight: FontWeight.w600)),
                  ),
                  for (final o in infoOptions.where((o) => o.group == g))
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Aqua.field,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Aqua.line),
                      ),
                      child: Row(
                        children: [
                          Icon(o.icon, color: Aqua.cyan, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(o.label,
                                style: const TextStyle(color: Aqua.text)),
                          ),
                          AquaSwitch(
                            value: selected.contains(o.key),
                            onChanged: (v) => toggle(o.key, v),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    setSheet(() {});
                    setState(() => selected = List.of(defaultInfo));
                    _saveSelection();
                  },
                  child: const Text('Voltar ao padrão'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.aquarium;
    final tiles = <Widget>[];
    final wide = <Widget>[];

    for (final key in selected) {
      switch (key) {
        case 'temp':
          tiles.add(_Tile(Icons.thermostat, a.temp, 1, '°C', 'Temperatura',
              offline: !a.connected));
        case 'ph':
          tiles.add(_Tile(Icons.water_drop_outlined, a.ph, 2, '', 'pH',
              offline: !a.connected));
        case 'sal':
          tiles.add(_Tile(Icons.waves, a.salinity, 1, '', 'Salinidade (ppt)',
              offline: !a.connected));
        case 't_kh':
        case 't_ca':
        case 't_mg':
        case 't_no3':
        case 't_po4':
          {
            final pk = key.substring(2);
            final p = testParams.firstWhere((t) => t.key == pk);
            final r = _latestTest(pk);
            final dec = pk == 'po4' ? 2 : (pk == 'kh' || pk == 'no3' ? 1 : 0);
            tiles.add(_Tile(
              Icons.science_outlined,
              r?.$1,
              dec,
              '',
              '${pk == 'kh' ? 'KH' : p.label}${p.unit.isEmpty ? '' : ' (${p.unit})'}',
              warn: r != null && (r.$1 < p.lo || r.$1 > p.hi),
              note: r == null ? 'sem teste' : r.$2,
              onTap: () => widget.onGo(8),
            ));
          }
        case 'alerts':
          if (a.connected && a.alarms.isNotEmpty) {
            wide.add(_WidePanel(
              icon: Icons.warning_amber,
              color: Aqua.amber,
              title: 'Alertas',
              background: const Color(0xFF3A1B12),
              onTap: () => widget.onGo(4),
              children: [
                for (final alarm in a.alarms)
                  Text('• $alarm', style: const TextStyle(color: Aqua.text)),
              ],
            ));
          }
        case 'levels':
          wide.add(_WidePanel(
            icon: Icons.water,
            color: Aqua.cyan,
            title: 'Níveis de água',
            onTap: () => widget.onGo(4),
            children: a.connected
                ? [
                    _Line(
                      'Sump',
                      a.tpaMinLevel
                          ? 'Nível mínimo'
                          : (a.atoSumpLow ? 'Baixo, repondo' : 'Normal'),
                      warn: a.tpaMinLevel || a.atoSumpLow,
                    ),
                    _Line('Galão de reposição',
                        a.atoReservoirEmpty ? 'Vazio' : 'Com água',
                        warn: a.atoReservoirEmpty),
                  ]
                : [const _Offline()],
          ));
        case 'outlets':
          {
            final on = a.outlets.where((o) => o.on).length;
            wide.add(_WidePanel(
              icon: Icons.power_outlined,
              color: Aqua.cyan,
              title: a.connected
                  ? 'Tomadas · $on de ${a.outlets.length} ligadas'
                  : 'Tomadas',
              onTap: () => widget.onGo(4),
              children: a.connected
                  ? [
                      for (final o in a.outlets)
                        _Line(o.name, o.on ? 'Ligada' : 'Desligada',
                            dim: !o.on),
                    ]
                  : [const _Offline()],
            ));
          }
        case 'tpa':
          wide.add(_WidePanel(
            icon: Icons.autorenew,
            color: Aqua.cyan,
            title: 'Troca de água (TPA)',
            onTap: () => widget.onGo(4),
            children: [
              if (!a.connected)
                const _Offline()
              else
                Text(
                  switch (a.tpaState) {
                    0 => 'Parada · ${a.tpaLiters.toStringAsFixed(0)} L por troca',
                    1 => 'Em andamento: retirando água do sump',
                    2 => 'Em andamento: aguardando',
                    _ => 'Em andamento: repondo água pronta',
                  },
                  style: TextStyle(
                      color: a.tpaState == 0 ? Aqua.text : Aqua.cyan),
                ),
            ],
          ));
        case 'animals':
          {
            int count(String k) => animals
                .where((x) => x.kind == k)
                .fold(0, (s, x) => s + x.qty);
            wide.add(_WidePanel(
              icon: Icons.set_meal_outlined,
              color: const Color(0xFFFF8A3D),
              title: 'Animais',
              onTap: () => widget.onGo(7),
              children: [
                Row(
                  children: [
                    for (final k in animalKinds)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(animalIcons[k], size: 18, color: kindColors[k]),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text('${count(k)} ${kindPlural[k]!.toLowerCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Aqua.text)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ));
          }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Etiqueta da seção, com o botão de escolher as informações
        SectionLabel(
          icon: Icons.water,
          text: 'AQUÁRIO',
          color: Aqua.teal,
          action: 'Personalizar',
          onAction: _customize,
        ),
        if (widget.connection != null)
          AquaPanel(
            borderColor: fade(Aqua.teal, 0.45),
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: widget.connection!,
            ),
          ),
        if (selected.isEmpty)
          AquaPanel(
            child: Text(
              'Nenhuma informação escolhida. Toque em Personalizar.',
              style: const TextStyle(color: Aqua.muted),
            ),
          ),
        // Cartões pequenos, três por linha
        for (var i = 0; i < tiles.length; i += 3)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                for (var k = i; k < i + 3; k++) ...[
                  if (k > i) const SizedBox(width: 10),
                  Expanded(child: k < tiles.length ? tiles[k] : const SizedBox()),
                ],
              ],
            ),
          ),
        if (tiles.isNotEmpty) const SizedBox(height: 2),
        ...wide,
      ],
    );
  }
}

/// Cartão pequeno: ícone, valor e nome.
class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.value, this.decimals, this.unit, this.label,
      {this.offline = false, this.warn = false, this.note, this.onTap});

  final IconData icon;
  final double? value;
  final int decimals;
  final String unit;
  final String label;
  final bool offline;
  final bool warn;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '--' : value!.toStringAsFixed(decimals);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [fade(Aqua.panelTop, 0.92), fade(Aqua.panel, 0.92)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: warn ? Aqua.amber : Aqua.line),
        ),
        child: Row(
          children: [
            Icon(icon, color: warn ? Aqua.amber : Aqua.text, size: 24),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('$text$unit',
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: Aqua.text)),
                  ),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Aqua.muted)),
                  if (offline || note != null)
                    Text(offline ? 'sem conexão' : note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            color: offline ? Aqua.amber : fade(Aqua.muted, 0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidePanel extends StatelessWidget {
  const _WidePanel({
    required this.icon,
    required this.color,
    required this.title,
    required this.children,
    this.onTap,
    this.background,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> children;
  final VoidCallback? onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return AquaPanel(
      padding: EdgeInsets.zero,
      color: background,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, color: Aqua.text)),
                  ),
                  const Icon(Icons.chevron_right, color: Aqua.muted, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.name, this.state, {this.warn = false, this.dim = false});

  final String name;
  final String state;
  final bool warn;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final color = warn ? Aqua.amber : (dim ? Aqua.muted : Aqua.green);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(name, style: const TextStyle(color: Aqua.text))),
          Text(state,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Offline extends StatelessWidget {
  const _Offline();

  @override
  Widget build(BuildContext context) => const Text(
        'Sem conexão com o ESP32.',
        style: TextStyle(color: Aqua.muted),
      );
}
