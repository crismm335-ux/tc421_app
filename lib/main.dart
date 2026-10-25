import 'package:flutter/material.dart';

import 'controller.dart';
import 'manual_page.dart';
import 'schedule_page.dart';

void main() => runApp(const Tc421App());

/// Visual de aquário marinho: fundo azul-profundo, destaques em azul escuro.
final ThemeData _marineTheme = () {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1D4ED8),
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF1D4ED8),
    onPrimary: Colors.white,
    surface: const Color(0xFF031019),
    surfaceContainer: const Color(0xFF0A2233),
    surfaceContainerHighest: const Color(0xFF0F2E45),
    outlineVariant: const Color(0xFF17405A),
    onSurfaceVariant: const Color(0xFF8FB0C8),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF031019),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF041526),
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF031019),
      indicatorColor: Color(0xFF12264F),
    ),
  );
}();

class Tc421App extends StatelessWidget {
  const Tc421App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TC421',
      debugShowCheckedModeBanner: false,
      theme: _marineTheme,
      darkTheme: _marineTheme,
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
                tooltip: 'IP da controladora',
                icon: const Icon(Icons.settings_ethernet),
                onPressed: () => _askIp(context),
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

  Future<void> _askIp(BuildContext context) async {
    final field = TextEditingController(text: controller.manualIp ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IP da controladora'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Veja o IP no painel do seu roteador (lista de aparelhos conectados). Deixe vazio para procurar por broadcast.'),
            const SizedBox(height: 12),
            TextField(
              controller: field,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '192.168.0.50',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
    if (result != null) await controller.setManualIp(result);
  }
}
