import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'aqua.dart';

const List<String> animalKinds = ['Peixe', 'Coral', 'Invertebrado'];

const Map<String, String> kindPlural = {
  'Peixe': 'Peixes',
  'Coral': 'Corais',
  'Invertebrado': 'Invertebrados',
};

const Map<String, IconData> animalIcons = {
  'Peixe': Icons.set_meal_outlined,
  'Coral': Icons.spa_outlined,
  'Invertebrado': Icons.bug_report_outlined,
};

const Map<String, Color> kindColors = {
  'Peixe': Color(0xFFFF8A3D),
  'Coral': Color(0xFFFF3D8B),
  'Invertebrado': Color(0xFF3FD2FF),
};

/// Tipos de cada grupo (opcional no cadastro).
const Map<String, List<String>> kindGroups = {
  'Peixe': [],
  'Coral': ['LPS', 'SPS', 'Mole', 'Anêmona'],
  'Invertebrado': ['Camarão', 'Caranguejo', 'Ermitão', 'Caramujo', 'Ouriço', 'Estrela'],
};

/// Sugestões de nome que aparecem ao cadastrar.
const Map<String, List<String>> kindExamples = {
  'Peixe': ['Palhaço ocellaris', 'Cirurgião amarelo', 'Gobi', 'Donzela'],
  'Coral': ['Euphyllia (martelo)', 'Acropora', 'Zoanthus', 'Montipora', 'Favia'],
  'Invertebrado': ['Camarão limpador', 'Ermitão pata azul', 'Caramujo Turbo', 'Ouriço'],
};

String dateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class Animal {
  Animal({
    required this.name,
    required this.kind,
    this.group = '',
    this.qty = 1,
    this.notes = '',
    String? date,
  }) : date = date ?? dateLabel(DateTime.now());

  String name;
  String kind;
  String group;
  int qty;
  String notes;
  String date;

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind,
        'group': group,
        'qty': qty,
        'notes': notes,
        'date': date,
      };

  factory Animal.fromJson(Map<String, dynamic> j) => Animal(
        name: (j['name'] ?? '') as String,
        kind: (j['kind'] ?? 'Peixe') as String,
        group: (j['group'] ?? '') as String,
        qty: (j['qty'] ?? 1) as int,
        notes: (j['notes'] ?? '') as String,
        date: j['date'] as String?,
      );

  /// "Coral LPS", "Invertebrado · Camarão", "Peixe".
  String get kindLabel => group.isEmpty ? kind : '$kind $group';
}

/// Aba "Animais": peixes, corais e invertebrados do aquário.
class AnimalsPage extends StatefulWidget {
  const AnimalsPage({super.key});

  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  static const _key = 'animals_v1';
  final List<Animal> animals = [];
  String filter = 'Todos';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => Animal.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => animals..clear()..addAll(list));
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(animals.map((a) => a.toJson()).toList()));
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

  Future<void> _edit({Animal? animal, String? newKind}) async {
    final name = TextEditingController(text: animal?.name ?? '');
    final notes = TextEditingController(text: animal?.notes ?? '');
    var kind = animal?.kind ?? newKind ?? 'Peixe';
    var group = animal?.group ?? '';
    var qty = animal?.qty ?? 1;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Aqua.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    animal == null
                        ? 'Novo ${kind.toLowerCase()}'
                        : 'Editar ${kind.toLowerCase()}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Aqua.text)),
                const SizedBox(height: 14),
                const Text('Grupo', style: TextStyle(color: Aqua.muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in animalKinds)
                      ChoiceChip(
                        avatar: Icon(animalIcons[k], size: 18, color: kindColors[k]),
                        label: Text(k),
                        selected: kind == k,
                        onSelected: (_) => setSheet(() {
                          kind = k;
                          group = '';
                        }),
                      ),
                  ],
                ),
                if (kindGroups[kind]!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Tipo', style: TextStyle(color: Aqua.muted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in kindGroups[kind]!)
                        ChoiceChip(
                          label: Text(g),
                          selected: group == g,
                          onSelected: (_) =>
                              setSheet(() => group = group == g ? '' : g),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: name,
                  style: const TextStyle(color: Aqua.text),
                  decoration: _field('Nome'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final ex in kindExamples[kind]!)
                      ActionChip(
                        label: Text(ex, style: const TextStyle(fontSize: 12)),
                        onPressed: () => setSheet(() => name.text = ex),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Quantidade', style: TextStyle(color: Aqua.text)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed:
                          qty > 1 ? () => setSheet(() => qty--) : null,
                    ),
                    Text('$qty',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Aqua.text)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setSheet(() => qty++),
                    ),
                  ],
                ),
                TextField(
                  controller: notes,
                  style: const TextStyle(color: Aqua.text),
                  decoration: _field('Observações (posição, alimentação...)'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (animal != null)
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, 'delete'),
                        child: const Text('Remover'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'save'),
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == 'save' && name.text.trim().isNotEmpty) {
      setState(() {
        if (animal == null) {
          animals.add(Animal(
              name: name.text.trim(),
              kind: kind,
              group: group,
              qty: qty,
              notes: notes.text.trim()));
        } else {
          animal
            ..name = name.text.trim()
            ..kind = kind
            ..group = group
            ..qty = qty
            ..notes = notes.text.trim();
        }
      });
      await _save();
    } else if (result == 'delete' && animal != null) {
      setState(() => animals.remove(animal));
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    int count(String k) =>
        animals.where((a) => a.kind == k).fold(0, (s, a) => s + a.qty);
    final kinds = filter == 'Todos' ? animalKinds : [filter];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      children: [
        // Contagem por grupo (toque filtra)
        Row(
          children: [
            for (final k in animalKinds) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => filter = filter == k ? 'Todos' : k),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Aqua.field,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: filter == k ? kindColors[k]! : Aqua.line,
                          width: filter == k ? 1.6 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(animalIcons[k], size: 18, color: kindColors[k]),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(kindPlural[k]!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Aqua.muted, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${count(k)}',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Aqua.text)),
                      ],
                    ),
                  ),
                ),
              ),
              if (k != animalKinds.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 12),
        AquaTabs(
          labels: const ['Todos', 'Peixes', 'Corais', 'Invert.'],
          selected: ['Todos', ...animalKinds]
              .indexOf(filter)
              .clamp(0, 3)
              .toInt(),
          onChanged: (i) => setState(
              () => filter = ['Todos', 'Peixe', 'Coral', 'Invertebrado'][i]),
        ),
        const SizedBox(height: 14),
        for (final k in kinds) ..._section(k),
      ],
    );
  }

  /// Um grupo: título com total, os cadastrados e o botão de adicionar.
  List<Widget> _section(String k) {
    final list = animals.where((a) => a.kind == k).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final color = kindColors[k]!;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2),
        child: Row(
          children: [
            Icon(animalIcons[k], color: color, size: 20),
            const SizedBox(width: 8),
            Text(kindPlural[k]!,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600, color: Aqua.text)),
            const Spacer(),
            Text('${list.length} ${list.length == 1 ? 'espécie' : 'espécies'}',
                style: const TextStyle(fontSize: 12, color: Aqua.muted)),
          ],
        ),
      ),
      if (list.isEmpty)
        AquaPanel(
          padding: const EdgeInsets.all(14),
          child: Text(
            'Nenhum ${k == 'Coral' ? 'coral' : k.toLowerCase()} cadastrado ainda.',
            style: const TextStyle(color: Aqua.muted),
          ),
        ),
      for (final a in list)
        AquaPanel(
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _edit(animal: a),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
              child: Row(
                children: [
                  AquaOrb(icon: animalIcons[a.kind]!, color: color, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, color: Aqua.text)),
                        Text(
                            '${a.kindLabel} · desde ${a.date}${a.notes.isEmpty ? '' : '\n${a.notes}'}',
                            style: const TextStyle(
                                fontSize: 12, color: Aqua.muted)),
                      ],
                    ),
                  ),
                  Text('×${a.qty}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Aqua.text)),
                ],
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 2),
        child: OutlinedButton.icon(
          icon: Icon(Icons.add, color: color),
          label: Text('Adicionar ${k == 'Coral' ? 'coral' : k.toLowerCase()}'),
          onPressed: () => _edit(newKind: k),
        ),
      ),
    ];
  }
}
