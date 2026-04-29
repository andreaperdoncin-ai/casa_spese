import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/spesa_provider.dart';
import '../models/categoria.dart';

class StatisticheScreen extends StatefulWidget {
  const StatisticheScreen({super.key});

  @override
  State<StatisticheScreen> createState() => _StatisticheScreenState();
}

class _StatisticheScreenState extends State<StatisticheScreen> {
  int _annoSelezionato = DateTime.now().year;
  int _touchedIndex = -1;

  final _mesi = [
    'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
    'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SpesaProvider>();
    final anni = provider.anniDisponibili;

    // Aggiungi sempre l'anno corrente anche se non ci sono spese
    final anniConCorrente = {...anni, DateTime.now().year}.toList()
      ..sort((a, b) => b.compareTo(a));

    if (!anniConCorrente.contains(_annoSelezionato)) {
      _annoSelezionato = anniConCorrente.first;
    }

    final totaleAnno = provider.totaleAnnoPerCompetenza(_annoSelezionato);
    final perCat = provider.totalePerCategoriaCompetenza(_annoSelezionato);
    final perMese = provider.totalePerMeseCompetenza(_annoSelezionato);
    final media = totaleAnno / 12;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiche'),
      ),
      body: Column(
        children: [
          // ---- Selettore anno prominente ----
          _AnnoSelector(
            anni: anniConCorrente,
            annoSelezionato: _annoSelezionato,
            onChanged: (y) => setState(() {
              _annoSelezionato = y;
              _touchedIndex = -1;
            }),
          ),

          // ---- Contenuto scrollabile ----
          Expanded(
            child: totaleAnno == 0
                ? const Center(
                    child: Text('Nessuna spesa di competenza per questo anno'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      // Riepilogo
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Totale anno',
                              value:
                                  '€ ${NumberFormat('#,##0.00', 'it_IT').format(totaleAnno)}',
                              icon: Icons.summarize_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              sublabel: 'per competenza $_annoSelezionato',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Media mensile',
                              value:
                                  '€ ${NumberFormat('#,##0.00', 'it_IT').format(media)}',
                              icon: Icons.calendar_month_outlined,
                              color: Colors.teal,
                              sublabel: 'totale ÷ 12',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Grafico torta
                      _ChartCard(
                        title: 'Distribuzione per categoria',
                        subtitle: 'competenza $_annoSelezionato',
                        child: _buildPieChart(
                            perCat, provider.categorie, totaleAnno),
                      ),

                      const SizedBox(height: 12),
                      _buildLegenda(perCat, provider.categorie, totaleAnno),

                      const SizedBox(height: 20),

                      // Grafico barre
                      _ChartCard(
                        title: 'Andamento mensile',
                        subtitle: 'quota di competenza per mese',
                        child: _buildBarChart(perMese),
                      ),

                      const SizedBox(height: 20),

                      // Tabella categorie
                      const Text('Dettaglio per categoria',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        'Importi ripartiti per competenza',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 12),
                      ...perCat.entries.map((e) {
                        final cat = provider.getCategoriaById(e.key);
                        if (cat == null) return const SizedBox.shrink();
                        final pct =
                            totaleAnno > 0 ? e.value / totaleAnno * 100 : 0;
                        return _CatRow(
                          cat: cat,
                          importo: e.value,
                          percentuale: pct.toDouble(),
                          media: e.value / 12,
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(
      Map<int, double> perCat, List<Categoria> categorie, double totale) {
    final entries = perCat.entries.toList();
    final sections = entries.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final cat = categorie.firstWhere((c) => c.id == e.key,
          orElse: () =>
              Categoria(nome: '?', icona: 'category', colore: 0xFF9E9E9E));
      final isTouched = i == _touchedIndex;
      return PieChartSectionData(
        color: cat.color,
        value: e.value,
        title: isTouched
            ? '€${NumberFormat('#,##0', 'it_IT').format(e.value)}'
            : '',
        radius: isTouched ? 65 : 55,
        titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white),
      );
    }).toList();

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 50,
          sectionsSpace: 2,
          pieTouchData: PieTouchData(
            touchCallback: (event, response) {
              setState(() {
                _touchedIndex =
                    response?.touchedSection?.touchedSectionIndex ?? -1;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLegenda(
      Map<int, double> perCat, List<Categoria> categorie, double totale) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: perCat.entries.map((e) {
        final cat = categorie.firstWhere((c) => c.id == e.key,
            orElse: () =>
                Categoria(nome: '?', icona: 'category', colore: 0xFF9E9E9E));
        final pct = totale > 0 ? e.value / totale * 100 : 0;
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cat.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cat.color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: cat.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(cat.nome,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Text('${pct.toStringAsFixed(0)}%',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarChart(Map<int, double> perMese) {
    final maxY = perMese.values.isEmpty
        ? 100.0
        : perMese.values.reduce((a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: List.generate(12, (i) {
            final mese = i + 1;
            final val = perMese[mese] ?? 0;
            return BarChartGroupData(
              x: mese,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: val > 0
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[200]!,
                  width: 18,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text(
                  _mesi[v.toInt() - 1],
                  style: const TextStyle(fontSize: 10),
                ),
                reservedSize: 24,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (v, _) => Text(
                  '€${NumberFormat('#,##0', 'it_IT').format(v)}',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey[200]!, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${_mesi[group.x - 1]}\n€${NumberFormat('#,##0.00', 'it_IT').format(rod.toY)}',
                const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Selettore anno prominente ----

class _AnnoSelector extends StatelessWidget {
  final List<int> anni;
  final int annoSelezionato;
  final ValueChanged<int> onChanged;

  const _AnnoSelector({
    required this.anni,
    required this.annoSelezionato,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      color: color.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Freccia sinistra
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: anni.indexOf(annoSelezionato) < anni.length - 1
                ? () => onChanged(
                    anni[anni.indexOf(annoSelezionato) + 1])
                : null,
            color: color,
          ),
          // Anno centrale
          GestureDetector(
            onTap: () => _showPicker(context),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                '$annoSelezionato',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          // Freccia destra
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: anni.indexOf(annoSelezionato) > 0
                ? () => onChanged(
                    anni[anni.indexOf(annoSelezionato) - 1])
                : null,
            color: color,
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Seleziona anno'),
        children: anni
            .map((y) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context);
                    onChanged(y);
                  },
                  child: Text(
                    '$y',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: y == annoSelezionato
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ---- Widget di supporto ----

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sublabel;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (sublabel != null)
              Text(sublabel!,
                  style: TextStyle(fontSize: 10, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard(
      {required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _CatRow extends StatelessWidget {
  final Categoria cat;
  final double importo;
  final double percentuale;
  final double media;

  const _CatRow({
    required this.cat,
    required this.importo,
    required this.percentuale,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'it_IT');
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(cat.iconData, color: cat.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      Text('Media: €${fmt.format(media)}/mese',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('€ ${fmt.format(importo)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${percentuale.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentuale / 100,
                backgroundColor: cat.color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(cat.color),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
