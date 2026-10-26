import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'aqua.dart';

const List<String> animalKinds = ['Peixe', 'Coral', 'Invertebrado'];

const Map<String, IconData> animalIcons = {
  'Peixe': Icons.set_meal_outlined,
  'Coral': Icons.spa_outlined,
  'Invertebrado': Icons.bug_report_outlined,
};

String dateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class Animal {
  Animal({
    required this.name,
    required this.kind,
    this.qty = 1,
    this.notes = '',
    String? date,
  }) : date = date ?? dateLabel(DateTime.now());

  String name;
  String kind;
  int qty;
  String notes;
  String date;

  Map<String, dynamic> toJson() =>
      {'name': name, 'kind': kind, 'qty': qty, 'notes': notes, 'date': date};

  factory Animal.fromJson(Map<String, dynamic> j) => Animal(
        name: (j['name'] ?? '') as String,
        kind: (j['kind'] ?? 'Peixe') as String,
        qty: (j['qty'] ?? 1) as int,
        notes: (j['notes'] ?? '') as String,
        date: j['date'] as String?,
      );
}

/// Aba "Animais": cadastro dos peixes, corais e invertebrados do aquário.
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

  Future<void> _edit([Animal? animal]) async {
    final name = TextEditingController(text: animal?.name ?? '');
    final notes = TextEditingController(text: animal?.notes ?? '');
    var kind = animal?.kind ?? 'Peixe';
    var qty = animal?.qty ?? 1;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Aqua.panel,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(animal == null ? 'Novo animal' : 'Editar animal',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                      labelText: 'Nome (ex.: Peixe-palhaço)'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final k in animalKinds)
                      ChoiceChip(
                        label: Text(k),
                        selected: kind == k,
                        onSelected: (_) => setSheet(() => kind = k),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Quantidade'),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed:
                          qty > 1 ? () => setSheet(() => qty--) : null,
                    ),
                    Text('$qty',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setSheet(() => qty++),
                    ),
                  ],
                ),
                TextField(
                  controller: notes,
                  decoration:
                      const InputDecoration(labelText: 'Observações'),
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
              qty: qty,
              notes: notes.text.trim()));
        } else {
          animal
            ..name = name.text.trim()
            ..kind = kind
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
    final shown =
        animals.where((a) => filter == 'Todos' || a.kind == filter).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            for (final k in animalKinds) ...[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Aqua.field,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Aqua.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          const {
                            'Peixe': 'Peixes',
                            'Coral': 'Corais',
                            'Invertebrado': 'Invertebrados',
                          }[k]!,
                          style: const TextStyle(
                              color: Aqua.muted, fontSize: 12)),
                      Text('${count(k)}',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              if (k != animalKinds.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 12),
        AquaTabs(
          labels: const ['Todos', 'Peixe', 'Coral', 'Invert.'],
          selected: ['Todos', ...animalKinds]
              .indexOf(filter)
              .clamp(0, 3)
              .toInt(),
          onChanged: (i) => setState(
              () => filter = ['Todos', 'Peixe', 'Coral', 'Invertebrado'][i]),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          const AquaPanel(
            child: Text(
              'Nenhum animal cadastrado. Toque em "Adicionar animal" para começar.',
              style: TextStyle(color: Aqua.muted),
            ),
          ),
        for (final a in shown)
          AquaPanel(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(animalIcons[a.kind], color: Aqua.cyan),
              title: Text(a.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${a.kind} · desde ${a.date}${a.notes.isEmpty ? '' : '\n${a.notes}'}'),
              isThreeLine: a.notes.isNotEmpty,
              trailing: Text('×${a.qty}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              onTap: () => _edit(a),
            ),
          ),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Adicionar animal'),
          onPressed: () => _edit(),
        ),
      ],
    );
  }
}
