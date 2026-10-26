import 'package:flutter/material.dart';

import 'animals_page.dart';
import 'aqua.dart';
import 'aquarium.dart';
import 'controller.dart';
import 'connection_panel.dart';
import 'equipment_page.dart';
import 'home_page.dart';
import 'manual_page.dart';
import 'profiles_page.dart';
import 'schedule_page.dart';
import 'tests_page.dart';

void main() => runApp(const Tc421App());

class Tc421App extends StatelessWidget {
  const Tc421App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AQUA LIGHT',
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
  int lumSub = 1; // 0 Canais, 1 Programação, 2 Perfis, 3 Conexão

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
  /// 2 programação, 3 perfis, 4 aquário, 5 conexão da luminária.
  void _go(int code) => setState(() {
        if (code == 0) {
          tab = 0;
        } else if (code == 4) {
          tab = 2;
        } else {
          tab = 1;
          lumSub = code == 5 ? 3 : code - 1;
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
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: AquaTabs(
                    labels: const ['Canais', 'Programação', 'Perfis', 'Conexão'],
                    selected: lumSub,
                    onChanged: (i) => setState(() => lumSub = i),
                  ),
                ),
                Expanded(
                  child: switch (lumSub) {
                    0 => ManualPage(controller: controller),
                    1 => SchedulePage(controller: controller),
                    2 => ProfilesPage(controller: controller),
                    _ => ListView(
                        padding: const EdgeInsets.all(12),
                        children: [ConnectionPanel(controller: controller)],
                      ),
                  },
                ),
              ],
            ),
          2 => EquipmentPage(aquarium: aquarium),
          3 => const AnimalsPage(),
          _ => const TestsPage(),
        };
        return Scaffold(
          backgroundColor: Aqua.bg,
          body: AquaBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (tab != 0)
                    AquaTitleBar(
                        title: const ['', 'Luminária', 'Equipamentos', 'Animais', 'Testes'][tab]),
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
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Início'),
              NavigationDestination(
                  icon: Icon(Icons.lightbulb_outline),
                  selectedIcon: Icon(Icons.lightbulb),
                  label: 'Luminária'),
              NavigationDestination(
                  icon: Icon(Icons.power_outlined),
                  selectedIcon: Icon(Icons.power),
                  label: 'Equipamentos'),
              NavigationDestination(
                  icon: Icon(Icons.set_meal_outlined),
                  selectedIcon: Icon(Icons.set_meal),
                  label: 'Animais'),
              NavigationDestination(
                  icon: Icon(Icons.science_outlined),
                  selectedIcon: Icon(Icons.science),
                  label: 'Testes'),
            ],
          ),
        );
      },
    );
  }
}
