import 'package:flutter/material.dart';

import 'controller.dart';
import 'manual_page.dart';
import 'schedule_page.dart';

void main() => runApp(const Tc421App());

class Tc421App extends StatelessWidget {
  const Tc421App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TC421',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
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
    controller.connect();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Controladora TC421')),
          body: Column(
            children: [
              _ConnectionCard(controller: controller),
              Expanded(
                child: tab == 0
                    ? ManualPage(controller: controller)
                    : SchedulePage(controller: controller),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.tune), label: 'Controle'),
              NavigationDestination(
                  icon: Icon(Icons.schedule), label: 'Cronograma'),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.controller});

  final Tc421Controller controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: controller.connected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(controller.connected ? Icons.wifi : Icons.wifi_off),
            const SizedBox(width: 12),
            Expanded(child: Text(controller.status)),
            if (controller.searching)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              if (controller.connected)
                IconButton(
                  tooltip: 'Sincronizar hora',
                  icon: const Icon(Icons.access_time),
                  onPressed: controller.syncTime,
                ),
              IconButton(
                tooltip: 'Procurar novamente',
                icon: const Icon(Icons.refresh),
                onPressed: controller.connect,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
