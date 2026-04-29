// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/spesa_provider.dart';
import 'screens/home_screen.dart';
import 'screens/statistiche_screen.dart';
import 'screens/contatori_screen.dart';
import 'screens/impostazioni_screen.dart';
import 'screens/aggiungi_spesa_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT', null);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => SpesaProvider()..loadAll(),
      child: const CasaSpeseApp(),
    ),
  );
}

class CasaSpeseApp extends StatelessWidget {
  const CasaSpeseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spese Casa Niguarda',
      debugShowCheckedModeBanner: false,
      locale: const Locale('it', 'IT'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it', 'IT'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  String? _selectedSpesaId;
  static const double _tabletBreakpoint = 720;

  // Indici: 0=Spese, 1=Statistiche, 2=Contatori, 3=Impostazioni
  final _labels = ['Spese', 'Statistiche', 'Contatori', 'Impostazioni'];
  final _icons = <(IconData, IconData)>[
    (Icons.receipt_long_outlined,  Icons.receipt_long),
    (Icons.bar_chart_outlined,     Icons.bar_chart),
    (Icons.speed_outlined,         Icons.speed),
    (Icons.settings_outlined,      Icons.settings),
  ];

  void _onDestinationSelected(int i) {
    setState(() {
      _currentIndex = i;
      _selectedSpesaId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= _tabletBreakpoint;
    if (isTablet) return _buildTabletLayout(context);
    return _buildPhoneLayout(context);
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(selectedSpesaId: null, onSpesaSelected: (_) {}),
          const StatisticheScreen(),
          const ContatoriScreen(),
          const ImpostazioniScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: List.generate(_labels.length, (i) => NavigationDestination(
          icon: Icon(_icons[i].$1),
          selectedIcon: Icon(_icons[i].$2),
          label: _labels[i],
        )),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            backgroundColor: colorScheme.surface,
            indicatorColor: colorScheme.primaryContainer,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.home, color: Colors.white, size: 24),
              ),
            ),
            destinations: List.generate(_labels.length, (i) => NavigationRailDestination(
              icon: Icon(_icons[i].$1),
              selectedIcon: Icon(_icons[i].$2),
              label: Text(_labels[i]),
            )),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _currentIndex == 0
                ? Row(children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.36,
                      child: HomeScreen(
                        selectedSpesaId: _selectedSpesaId,
                        onSpesaSelected: (id) => setState(() => _selectedSpesaId = id),
                      ),
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(
                      child: _selectedSpesaId == null
                          ? const _DetailPlaceholder()
                          : SpesaDetailPanel(spesaId: _selectedSpesaId!),
                    ),
                  ])
                : IndexedStack(
                    index: _currentIndex,
                    children: [
                      const SizedBox.shrink(),
                      const StatisticheScreen(),
                      const ContatoriScreen(),
                      const ImpostazioniScreen(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Seleziona una spesa', style: TextStyle(fontSize: 16, color: Colors.grey[400])),
          const SizedBox(height: 8),
          Text('oppure aggiungine una nuova', style: TextStyle(fontSize: 13, color: Colors.grey[350])),
        ],
      ),
    );
  }
}

class SpesaDetailPanel extends StatelessWidget {
  final String spesaId;
  const SpesaDetailPanel({super.key, required this.spesaId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SpesaProvider>();
    final spesa = provider.spese.where((s) => s.id == spesaId).firstOrNull;
    if (spesa == null) return const _DetailPlaceholder();
    final cat = provider.getCategoriaById(spesa.categoriaId);
    final df  = DateFormat('d MMMM yyyy', 'it_IT');
    final fmt = NumberFormat('#,##0.00', 'it_IT');
    final color = cat?.color ?? Colors.grey;
    return Scaffold(
      appBar: AppBar(
        title: Text(cat?.nome ?? 'Dettaglio'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => AggiungiSpesaScreen(spesaDaModificare: spesa))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: Column(children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Icon(cat?.iconData ?? Icons.category, color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text('€ ${fmt.format(spesa.importo)}',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: color)),
            Text(cat?.nome ?? '', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ])),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          _DetailRow(icon: Icons.calendar_today_outlined,
            label: 'Data pagamento', value: df.format(spesa.data)),
          if (spesa.competenzaInizio != null)
            _DetailRow(icon: Icons.date_range_outlined, label: 'Competenza',
              value: '${df.format(spesa.competenzaInizio!)} → ${df.format(spesa.competenzaFine!)}'),
          if (spesa.kwh != null)
            _DetailRow(icon: Icons.bolt_outlined, label: 'Consumo',
              value: '${spesa.kwh!.toStringAsFixed(0)} kWh'),
          if (spesa.canoneRai != null)
            _DetailRow(icon: Icons.tv_outlined, label: 'Canone RAI',
              value: '€ ${fmt.format(spesa.canoneRai!)}'),
          if (spesa.note != null && spesa.note!.isNotEmpty)
            _DetailRow(icon: Icons.notes_outlined, label: 'Note', value: spesa.note!),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          )),
        ],
      ),
    );
  }
}
