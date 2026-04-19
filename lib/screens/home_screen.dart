import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/spesa_provider.dart';
import '../models/spesa.dart';
import '../models/categoria.dart';
import 'aggiungi_spesa_screen.dart';

class HomeScreen extends StatelessWidget {
  final String? selectedSpesaId;
  final ValueChanged<String?>? onSpesaSelected;

  const HomeScreen({
    super.key,
    this.selectedSpesaId,
    this.onSpesaSelected,
  });

  // In modalità tablet la selezione è gestita dall'esterno
  bool get _isTabletMode => onSpesaSelected != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spese Casa Niguarda'),
        actions: [
          Consumer<SpesaProvider>(
            builder: (_, p, __) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '€ ${NumberFormat('#,##0.00', 'it_IT').format(p.totaleAnnoCorrente)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${DateTime.now().year}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Consumer<SpesaProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.spese.isEmpty) {
            return const _EmptyState();
          }
          return _SpeseList(
            spese: provider.spese,
            selectedSpesaId: selectedSpesaId,
            onSpesaSelected: onSpesaSelected,
            isTabletMode: _isTabletMode,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AggiungiSpesaScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nuova spesa'),
      ),
    );
  }
}

class _SpeseList extends StatelessWidget {
  final List<Spesa> spese;
  final String? selectedSpesaId;
  final ValueChanged<String?>? onSpesaSelected;
  final bool isTabletMode;

  const _SpeseList({
    required this.spese,
    required this.selectedSpesaId,
    required this.onSpesaSelected,
    required this.isTabletMode,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Spesa>> grouped = {};
    final monthFormat = DateFormat('MMMM yyyy', 'it_IT');
    for (final s in spese) {
      final key = monthFormat.format(s.data);
      grouped.putIfAbsent(key, () => []).add(s);
    }
    final keys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: keys.length,
      itemBuilder: (ctx, i) {
        final key = keys[i];
        final group = grouped[key]!;
        final totale = group.fold(0.0, (s, e) => s + e.importo);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    key.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(ctx).colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '€ ${NumberFormat('#,##0.00', 'it_IT').format(totale)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            ...group.map((s) => _SpesaTile(
                  spesa: s,
                  isSelected: selectedSpesaId == s.id,
                  isTabletMode: isTabletMode,
                  onTap: () {
                    if (isTabletMode) {
                      onSpesaSelected?.call(s.id);
                    } else {
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) =>
                              AggiungiSpesaScreen(spesaDaModificare: s),
                        ),
                      );
                    }
                  },
                )),
          ],
        );
      },
    );
  }
}

class _SpesaTile extends StatelessWidget {
  final Spesa spesa;
  final bool isSelected;
  final bool isTabletMode;
  final VoidCallback onTap;

  const _SpesaTile({
    required this.spesa,
    required this.isSelected,
    required this.isTabletMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM', 'it_IT');
    final cat = context.read<SpesaProvider>().getCategoriaById(spesa.categoriaId);
    final color = cat != null ? cat.color : Colors.grey;
    final icon = cat?.iconData ?? Icons.category;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: isSelected ? colorScheme.primaryContainer.withOpacity(0.4) : null,
      shape: isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.primary, width: 1.5),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spesa.catNome ?? 'Categoria',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          df.format(spesa.data),
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (spesa.competenzaInizio != null) ...[
                          Text(' · ',
                              style: TextStyle(color: Colors.grey[400])),
                          Flexible(
                            child: Text(
                              '${df.format(spesa.competenzaInizio!)} - ${df.format(spesa.competenzaFine!)}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (spesa.note != null && spesa.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        spesa.note!,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '€ ${NumberFormat('#,##0.00', 'it_IT').format(spesa.importo)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (spesa.kwh != null)
                    Text(
                      '${spesa.kwh!.toStringAsFixed(0)} kWh',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Nessuna spesa registrata',
              style: TextStyle(fontSize: 16, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('Tocca + per aggiungere la prima',
              style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }
}
