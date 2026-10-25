import 'package:flutter/material.dart';

import 'aqua.dart';
import 'controller.dart';
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
  int tab = 0;

  @override
  void initState() {
    super.initState();
    controller.loadSettings().then((_) => controller.connect());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _go(int index) => setState(() => tab = index);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pages = <Widget>[
          HomePage(controller: controller, onGo: _go),
          ManualPage(controller: controller),
          SchedulePage(controller: controller),
          ProfilesPage(controller: controller),
        ];
        return Scaffold(
          backgroundColor: Aqua.bg,
          body: AquaBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _Header(controller: controller),
                  Expanded(child: pages[tab]),
                ],
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: _go,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined), label: 'Início'),
              NavigationDestination(icon: Icon(Icons.tune), label: 'Canais'),
              NavigationDestination(
                  icon: Icon(Icons.schedule), label: 'Programação'),
              NavigationDestination(
                  icon: Icon(Icons.star_border), label: 'Perfis'),
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
