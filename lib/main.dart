import 'package:flutter/material.dart';

import 'aqua.dart';
import 'aquarium.dart';
import 'controller.dart';
import 'equipment_page.dart';
import 'home_page.dart';
import 'manual_page.dart';
import 'profiles_page.dart';
import 'schedule_page.dart';

void main() => runApp(const Tc421App());

class Tc421App extends StatelessWidget {
  const Tc421App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aqua Light TC421',
      debugShowCheckedModeBanner: false,
      theme: aquaTheme,
      darkTheme: aquaTheme,
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final Tc421Controller controller = Tc421Controller();
  final AquariumController aquarium = AquariumController();
  int tab = 0; // 0 Início, 1 Luminária, 2 Aquário
  int lumSub = 1; // 0 Canais, 1 Programação, 2 Perfis

  @override
  void initState() {
    super.initState();
    controller.loadSettings().then((_) => controller.connect());
    aquarium.start();
  }

  @override
  void dispose() {
    controller.dispose();
    aquarium.dispose();
    super.dispose();
  }

  /// Códigos usados pelos botões das telas: 0 início, 1 canais,
  /// 2 programação, 3 perfis, 4 aquário.
  void _go(int code) => setState(() {
        if (code == 0) {
          tab = 0;
        } else if (code == 4) {
          tab = 2;
        } else {
          tab = 1;
          lumSub = code - 1;
        }
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, aquarium]),
      builder: (context, _) {
        // Só a aba aberta é montada.
        final Widget page = switch (tab) {
          0 => HomePage(controller: controller, aquarium: aquarium, onGo: _go),
          1 => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Canais')),
                        ButtonSegment(value: 1, label: Text('Programação')),
                        ButtonSegment(value: 2, label: Text('Perfis')),
                      ],
                      selected: {lumSub},
                      onSelectionChanged: (s) =>
                          setState(() => lumSub = s.first),
                    ),
                  ),
                ),
                Expanded(
                  child: switch (lumSub) {
                    0 => ManualPage(controller: controller),
                    1 => SchedulePage(controller: controller),
                    _ => ProfilesPage(controller: controller),
                  },
                ),
              ],
            ),
          _ => EquipmentPage(aquarium: aquarium),
        };
        return Scaffold(
          backgroundColor: Aqua.bg,
          body: AquaBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _Header(controller: controller),
                  Expanded(child: RepaintBoundary(child: page)),
                ],
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            // Luminária reabre na última aba usada.
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined), label: 'Início'),
              NavigationDestination(
                  icon: Icon(Icons.lightbulb_outline), label: 'Luminária'),
              NavigationDestination(
                  icon: Icon(Icons.water_outlined), label: 'Aquário'),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final Tc421Controller controller;

  @override
  Widget build(BuildContext context) {
    final text = controller.connected
        ? '● CONECTADA'
        : controller.searching
            ? '● PROCURANDO'
            : '● SEM CONEXÃO';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Color(0xEF031226),
        border: Border(bottom: BorderSide(color: Aqua.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  const TextSpan(
                    text: 'AQUA ',
                    children: [
                      TextSpan(
                          text: 'LIGHT', style: TextStyle(color: Aqua.cyan)),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Aqua.text,
                  ),
                ),
                const Text(
                  'TC421 · MARINE LIGHTING CONTROL',
                  style: TextStyle(
                      fontSize: 10, letterSpacing: 2, color: Aqua.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xFF1B628E)),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: controller.connected
                    ? const Color(0xFF8FEEFF)
                    : Aqua.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
