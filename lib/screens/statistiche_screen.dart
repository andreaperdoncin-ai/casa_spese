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

  final _mesi = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SpesaProvider>();
    final anni = provider.anniDisponibili;
    if (!anni.contains(_annoSelezionato) && anni.isNotEmpty) {
      _annoSelezionato = anni.first;
    }

    final speseAnno = provider.spese.where((s) => s.data.year == _annoSelezionato).toList();
    final totaleAnno = speseAnno.fold(0.0, (s, e) => s + e.importo);

    // Per categoria
    final Map<int, double> perCat = {};
    for (final s in speseAnno) {
      perCat[s.categoriaId] = (perCat[s.categoriaId] ?? 0) + s.importo;
    }

    // Per mese
    final Map<int, double> perMese = {};
    for (final s in speseAnno) {
      perMese[s.data.month] = (perMese[s.data.month] ?? 0) + s.importo;
    }

    final media = totaleAnno / 12;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiche'),
        actions: [
          if (anni.length > 1)
            PopupMenuButton<int>(
              initialValue: _annoSelezionato,
              onSelected: (y) => setState(() => _annoSelezionato = y),
              itemBuilder: (_) => anni
                  .map((y) => PopupMenuItem(value: y, child: Text('$y')))
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$_annoSelezionato',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: speseAnno.isEmpty
          ? const Center(child: Text('Nessuna spesa per questo anno'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Riepilogo
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Totale anno',
                        value: '€ ${NumberFormat('#,##0.00', 'it_IT').format(totaleAnno)}',
                        icon: Icons.summarize_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Media mensile',
                        value: '€ ${NumberFormat('#,##0.00', 'it_IT').format(media)}',
                        icon: Icons.calendar_month_outlined,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Grafico torta - distribuzione per categoria
                _ChartCard(
                  title: 'Distribuzione per categoria',
                  subtitle: '$_annoSelezionato',
                  child: _buildPieChart(perCat, provider.categorie, totaleAnno),
                ),

                const SizedBox(height: 16),

                // Legenda torta
                _buildLegenda(perCat, provider.categorie, totaleAnno),

                const SizedBox(height: 24),

                // Grafico barre - andamento mensile
                _ChartCard(
                  title: 'Andamento mensile',
                  subtitle: '$_annoSelezionato',
                  child: _buildBarChart(perMese),
                ),

                const SizedBox(height: 24),

                // Tabella per categoria
                const Text('Dettaglio per categoria',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ...perCat.entries.map((e) {
                  final cat = provider.getCategoriaById(e.key);
                  if (cat == null) return const SizedBox.shrink();
                  final pct = totaleAnno > 0 ? e.value / totaleAnno * 100 : 0;
                  return _CatRow(
                    cat: cat,
                    importo: e.value,
                    percentuale: pct.toDouble(),
                    media: e.value / 12,
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildPieChart(Map<int, double> perCat, List<Categoria> categorie, double totale) {
    final sections = perCat.entries.map((e) {
      final cat = categorie.firstWhere((c) => c.id == e.key,
          orElse: () => Categoria(nome: '?', icona: 'category', colore: 0xFF9E9E9E));
      final index = perCat.keys.toList().indexOf(e.key);
      final isTouched = index == _touchedIndex;
      return PieChartSectionData(
        color: cat.color,
        value: e.value,
        title: isTouched ? '€${NumberFormat('#,##0', 'it_IT').format(e.value)}' : '',
        radius: isTouched ? 65 : 55,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        badgeWidget: isTouched ? null : null,
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
                _touchedIndex = response?.touchedSection?.touchedSectionIndex ?? -1;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLegenda(Map<int, double> perCat, List<Categoria> categorie, double totale) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: perCat.entries.map((e) {
        final cat = categorie.firstWhere((c) => c.id == e.key,
            orElse: () => Categoria(nome: '?', icona: 'category', colore: 0xFF9E9E9E));
        final pct = totale > 0 ? e.value / totale * 100 : 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cat.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cat.color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(cat.nome, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Text('${pct.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarChart(Map<int, double> perMese) {
    final maxY = perMese.values.isEmpty ? 100.0 : perMese.values.reduce((a, b) => a > b ? a : b) * 1.2;

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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
                reservedSize: 50,
                getTitlesWidget: (v, _) => Text(
                  '€${NumberFormat('#,##0', 'it_IT').format(v)}',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '€${NumberFormat('#,##0.00', 'it_IT').format(rod.toY)}',
                const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

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
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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

  const _ChartCard({required this.title, required this.subtitle, required this.child});

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
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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

  const _CatRow({required this.cat, required this.importo, required this.percentuale, required this.media});

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
                      Text(cat.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Media: €${fmt.format(media)}/mese',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('€ ${fmt.format(importo)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${percentuale.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
