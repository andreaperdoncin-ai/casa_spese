import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/spesa_provider.dart';
import '../models/categoria.dart';

class ImpostazioniScreen extends StatelessWidget {
  const ImpostazioniScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        children: [
          const _SectionHeader('Categorie'),
          const _CategorieSection(),
          const _SectionHeader('Backup & Ripristino'),
          const _BackupSection(),
          const _SectionHeader('Informazioni'),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Casa Spese'),
            subtitle: const Text('Trilocale · Milano · v1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _CategorieSection extends StatelessWidget {
  const _CategorieSection();

  @override
  Widget build(BuildContext context) {
    final categorie = context.watch<SpesaProvider>().categorie;
    return Column(
      children: [
        ...categorie.map((cat) => ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(cat.iconData, color: cat.color, size: 18),
              ),
              title: Text(cat.nome),
              subtitle: cat.predefinita ? const Text('Predefinita') : null,
              trailing: !cat.predefinita
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(context, cat),
                    )
                  : null,
            )),
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('Aggiungi categoria'),
          onTap: () => _showAddDialog(context),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, Categoria cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina categoria'),
        content: Text('Eliminare "${cat.nome}"?\nLe spese associate rimarranno nel database.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<SpesaProvider>().deleteCategoria(cat.id!);
    }
  }

  void _showAddDialog(BuildContext context) {
    final nomeCtrl = TextEditingController();
    String iconaSelezionata = 'category';
    int coloreSelezionato = 0xFF607D8B;

    final iconeDisponibili = {
      'category': Icons.category,
      'home': Icons.home_outlined,
      'water_drop': Icons.water_drop_outlined,
      'local_gas_station': Icons.local_gas_station_outlined,
      'directions_car': Icons.directions_car_outlined,
      'local_hospital': Icons.local_hospital_outlined,
      'school': Icons.school_outlined,
      'shopping_cart': Icons.shopping_cart_outlined,
      'fitness_center': Icons.fitness_center_outlined,
      'restaurant': Icons.restaurant_outlined,
    };

    final coloriDisponibili = [
      0xFF1565C0, 0xFFB71C1C, 0xFF2E7D32, 0xFFF57F17,
      0xFF6A1B9A, 0xFF00695C, 0xFF37474F, 0xFFE65100,
      0xFF880E4F, 0xFF1A237E,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuova categoria'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome categoria',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Icona', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: iconeDisponibili.entries.map((e) {
                    final selected = iconaSelezionata == e.key;
                    return GestureDetector(
                      onTap: () => setDialogState(() => iconaSelezionata = e.key),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected ? Color(coloreSelezionato).withOpacity(0.2) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: selected ? Border.all(color: Color(coloreSelezionato), width: 2) : null,
                        ),
                        child: Icon(e.value, size: 20, color: selected ? Color(coloreSelezionato) : Colors.grey[600]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Colore', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: coloriDisponibili.map((c) {
                    final selected = coloreSelezionato == c;
                    return GestureDetector(
                      onTap: () => setDialogState(() => coloreSelezionato = c),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: selected ? Border.all(color: Colors.black, width: 2) : null,
                        ),
                        child: selected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            FilledButton(
              onPressed: () async {
                if (nomeCtrl.text.trim().isEmpty) return;
                final cat = Categoria(
                  nome: nomeCtrl.text.trim(),
                  icona: iconaSelezionata,
                  colore: coloreSelezionato,
                );
                await ctx.read<SpesaProvider>().addCategoria(cat);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Aggiungi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupSection extends StatelessWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SpesaProvider>();
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: const Text('Esporta backup'),
          subtitle: const Text('Salva o condividi un file JSON con tutti i dati'),
          onTap: () async {
            try {
              await provider.exportBackup();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Errore esportazione: $e')),
                );
              }
            }
          },
        ),
        const Divider(indent: 16, endIndent: 16, height: 1),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Importa backup'),
          subtitle: const Text('Carica un file JSON di backup (sostituisce tutti i dati)'),
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Importa backup'),
                content: const Text(
                  'Questa operazione sostituirà TUTTI i dati esistenti con quelli del backup.\n\nProcedere?',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Importa'),
                  ),
                ],
              ),
            );
            if (confirm != true || !context.mounted) return;

            final success = await provider.importBackup();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? 'Backup importato con successo!' : 'Importazione annullata o fallita'),
                  backgroundColor: success ? Colors.green : null,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
