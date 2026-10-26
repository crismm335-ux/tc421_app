import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'animals_page.dart' show dateLabel;
import 'aqua.dart';

class TestParam {
  const TestParam(this.key, this.label, this.unit, this.lo, this.hi);
  final String key;
  final String label;
  final String unit;
  final double lo;
  final double hi;
}

/// Faixas usuais de um aquário marinho de recife.
const List<TestParam> testParams = [
  TestParam('ph', 'pH', '', 8.0, 8.4),
  TestParam('sal', 'Salinidade', 'ppt', 33, 36),
  TestParam('kh', 'Alcalinidade (KH)', 'dKH', 7, 11),
  TestParam('ca', 'Cálcio', 'ppm', 400, 450),
  TestParam('mg', 'Magnésio', 'ppm', 1250, 1400),
  TestParam('no3', 'Nitrato', 'ppm', 0, 10),
  TestParam('po4', 'Fosfato', 'ppm', 0, 0.1),
  TestParam('nh3', 'Amônia', 'ppm', 0, 0.05),
];

class TestEntry {
  TestEntry(this.date, this.values);
  final String date;
  final Map<String, double> values;

  Map<String, dynamic> toJson() => {'date': date, 'v': values};

  factory TestEntry.fromJson(Map<String, dynamic> j) => TestEntry(
        j['date'] as String,
        {
          for (final e in (j['v'] as Map<String, dynamic>).entries)
            e.key: (e.value as num).toDouble(),
        },
      );
}

/// Aba "Testes": registro dos testes de água, com a faixa ideal de cada um.
class TestsPage extends StatefulWidget {
  const TestsPage({super.key});

  @override
  State<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends State<TestsPage> {
  static const _key = 'water_tests_v1';
  final List<TestEntry> entries = []; // mais novo primeiro

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
          .map((e) => TestEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => entries..clear()..addAll(list));
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  double? _latest(String key) {
    for (final e in entries) {
      final v = e.values[key];
      if (v != null) return v;
    }
    return null;
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _add() async {
    final ctrls = {for (final p in testParams) p.key: TextEditingController()};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Aqua.panel,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Novo teste',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const Text('Preencha só o que você testou.',
                  style: TextStyle(color: Aqua.muted)),
              const SizedBox(height: 8),
              for (final p in testParams)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: ctrls[p.key],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText:
                          '${p.label}${p.unit.isEmpty ? '' : ' (${p.unit})'}',
                      helperText: 'ideal ${_fmt(p.lo)} a ${_fmt(p.hi)}',
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final values = <String, double>{};
    for (final p in testParams) {
      final v = double.tryParse(ctrls[p.key]!.text.trim().replaceAll(',', '.'));
      if (v != null) values[p.key] = v;
    }
    if (values.isEmpty) return;
    setState(() => entries.insert(0, TestEntry(dateLabel(DateTime.now()), values)));
    await _save();
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
              const SectionTitle('Último resultado'),
              for (final p in testParams) _row(p),
            ],
          ),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Registrar teste'),
          onPressed: _add,
        ),
        const SizedBox(height: 12),
        AquaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Histórico'),
              if (entries.isEmpty)
                const Text('Nenhum teste registrado ainda.',
                    style: TextStyle(color: Aqua.muted)),
              for (var i = 0; i < entries.length; i++)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Aqua.field,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Aqua.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(entries[i].date,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              setState(() => entries.removeAt(i));
                              await _save();
                            },
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          for (final p in testParams)
                            if (entries[i].values[p.key] != null)
                              Text(
                                '${p.label.split(' ').first}: ${_fmt(entries[i].values[p.key]!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _inRange(p, entries[i].values[p.key]!)
                                      ? Aqua.muted
                                      : const Color(0xFFFFB347),
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _inRange(TestParam p, double v) => v >= p.lo && v <= p.hi;

  Widget _row(TestParam p) {
    final v = _latest(p.key);
    final ok = v != null && _inRange(p, v);
    final color = v == null
        ? Aqua.muted
        : (ok ? const Color(0xFF47E08A) : const Color(0xFFFFB347));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.label, style: const TextStyle(color: Aqua.text)),
                Text('ideal ${_fmt(p.lo)} a ${_fmt(p.hi)} ${p.unit}',
                    style: const TextStyle(fontSize: 11, color: Aqua.muted)),
              ],
            ),
          ),
          Text(v == null ? '—' : '${_fmt(v)} ${p.unit}',
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
