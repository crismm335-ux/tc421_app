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

  /// 0 Início, 1 Luminária, 2 Equipamentos, 3 Animais, 4 Testes.
  int tab = 0;

  /// Dentro de Luminária: 0 Canais, 1 Programação, 2 Perfis.
  int lumSub = 0;

  /// Tela de conexão da luminária aberta pela engrenagem.
  bool showConnection = false;

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
  /// 2 programação, 3 perfis, 4 equipamentos do aquário, 5 conexão da
  /// luminária, 7 animais, 8 testes.
  void _go(int code) => setState(() {
        showConnection = false;
        switch (code) {
          case 1:
          case 2:
          case 3:
            tab = 1;
            lumSub = code - 1;
          case 4:
            tab = 2;
          case 5:
            showConnection = true;
          case 7:
            tab = 3;
          case 8:
            tab = 4;
          default:
            tab = 0;
        }
      });

  Widget _titled(String title, Widget body,
      {VoidCallback? onBack, bool settings = true}) {
    return Column(
      children: [
        AquaTitleBar(
          title: title,
          onBack: onBack ?? () => _go(0),
          onSettings: settings ? () => _go(5) : null,
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _luminaria() {
    return _titled(
      'Luminária',
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: AquaTabs(
              labels: const ['Canais', 'Programação', 'Perfis'],
              selected: lumSub,
              onChanged: (i) => setState(() => lumSub = i),
            ),
          ),
          Expanded(
            child: switch (lumSub) {
              0 => ManualPage(controller: controller),
              1 => SchedulePage(controller: controller),
              _ => ProfilesPage(controller: controller, onGo: _go),
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cada tela só redesenha com o que ela usa: a Luminária não muda
    // quando o ESP32 manda leitura nova, e vice-versa.
    final Listenable listenable = showConnection
        ? controller
        : switch (tab) {
            0 => Listenable.merge([controller, aquarium]),
            1 => controller,
            2 => aquarium,
            _ => controller,
          };
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        // Só a tela aberta é montada.
        final Widget page = showConnection
            ? _titled(
                'Conexão',
                ListView(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  children: [ConnectionPanel(controller: controller)],
                ),
                onBack: () => setState(() => showConnection = false),
                settings: false)
            : switch (tab) {
                0 => HomePage(
                    controller: controller, aquarium: aquarium, onGo: _go),
                1 => _luminaria(),
                2 => _titled('Equipamentos', EquipmentPage(aquarium: aquarium)),
                3 => _titled('Animais', const AnimalsPage()),
                _ => _titled('Testes da água', const TestsPage()),
              };
        return Scaffold(
          backgroundColor: Aqua.bg,
          body: AquaBackground(
            child: SafeArea(
              bottom: false,
              child: RepaintBoundary(child: page),
            ),
          ),
          bottomNavigationBar: AquaBottomBar(
            selected: tab,
            onTap: (i) => setState(() {
              showConnection = false;
              tab = i;
            }),
            items: const [
              AquaNavItem(Icons.home_outlined, 'Início'),
              AquaNavItem(Icons.lightbulb_outline, 'Luminária'),
              AquaNavItem(Icons.power_outlined, 'Equipamentos'),
              AquaNavItem(Icons.set_meal_outlined, 'Animais'),
              AquaNavItem(Icons.science_outlined, 'Testes'),
            ],
          ),
        );
      },
    );
  }
}
