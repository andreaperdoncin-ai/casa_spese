import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../models/spesa.dart';
import '../models/categoria.dart';

class SpesaProvider extends ChangeNotifier {
  List<Spesa> _spese = [];
  List<Categoria> _categorie = [];
  bool _loading = false;
  String? _error;

  List<Spesa> get spese => _spese;
  List<Categoria> get categorie => _categorie;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    try {
      _categorie = await DatabaseHelper.instance.getCategorie();
      _spese = await DatabaseHelper.instance.getSpese();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> addSpesa(Spesa spesa) async {
    await DatabaseHelper.instance.insertSpesa(spesa);
    await loadAll();
  }

  /// Inserisce più spese in una sola transazione (per spese ripetute)
  Future<void> addSpeseBatch(List<Spesa> spese) async {
    await DatabaseHelper.instance.insertSpeseBatch(spese);
    await loadAll();
  }

  Future<void> updateSpesa(Spesa spesa) async {
    await DatabaseHelper.instance.updateSpesa(spesa);
    await loadAll();
  }

  Future<void> deleteSpesa(String id) async {
    await DatabaseHelper.instance.deleteSpesa(id);
    await loadAll();
  }

  Future<void> addCategoria(Categoria cat) async {
    await DatabaseHelper.instance.insertCategoria(cat);
    await loadAll();
  }

  Future<void> deleteCategoria(int id) async {
    await DatabaseHelper.instance.deleteCategoria(id);
    await loadAll();
  }

  Categoria? getCategoriaById(int id) {
    try {
      return _categorie.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---- STATISTICHE PER COMPETENZA ----

  /// Ripartisce una spesa sui mesi dell'anno [anno] in base al periodo
  /// di competenza. Se non ha competenza, usa il mese di pagamento.
  /// Restituisce una mappa mese -> quota di competenza.
  Map<int, double> _ripartisciPerMese(spesa, int anno) {
    final result = <int, double>{};

    if (spesa.competenzaInizio == null || spesa.competenzaFine == null) {
      // Nessuna competenza: attribuisci tutto al mese di pagamento se è nell'anno
      if (spesa.data.year == anno) {
        result[spesa.data.month] = spesa.importo;
      }
      return result;
    }

    final inizio = spesa.competenzaInizio!;
    final fine = spesa.competenzaFine!;

    // Durata totale in giorni della competenza
    final durataGiorni = fine.difference(inizio).inDays + 1;
    if (durataGiorni <= 0) return result;

    // Scorri mese per mese nell'intervallo di competenza
    DateTime cursore = DateTime(inizio.year, inizio.month, 1);
    while (!cursore.isAfter(DateTime(fine.year, fine.month, 1))) {
      if (cursore.year == anno) {
        // Intersezione tra il mese corrente e il periodo di competenza
        final meseInizio = DateTime(cursore.year, cursore.month, 1);
        final meseFine = DateTime(cursore.year, cursore.month + 1, 1)
            .subtract(const Duration(days: 1));

        final overlapInizio =
            inizio.isAfter(meseInizio) ? inizio : meseInizio;
        final overlapFine = fine.isBefore(meseFine) ? fine : meseFine;

        if (!overlapInizio.isAfter(overlapFine)) {
          final giorniMese = overlapFine.difference(overlapInizio).inDays + 1;
          final quota = spesa.importo * giorniMese / durataGiorni;
          result[cursore.month] = (result[cursore.month] ?? 0) + quota;
        }
      }
      // Avanza al mese successivo
      cursore = DateTime(cursore.year, cursore.month + 1, 1);
    }

    return result;
  }

  /// Totale di competenza per un dato anno (somma quote di tutti i mesi)
  double totaleAnnoPerCompetenza(int anno) {
    double totale = 0;
    for (final s in _spese) {
      final quote = _ripartisciPerMese(s, anno);
      totale += quote.values.fold(0.0, (a, b) => a + b);
    }
    return totale;
  }

  double get totaleAnnoCorrente => totaleAnnoPerCompetenza(DateTime.now().year);

  double get mediaMensileAnnoCorrente => totaleAnnoCorrente / 12;

  /// Mappa mese -> importo di competenza per l'anno dato
  Map<int, double> totalePerMeseCompetenza(int anno) {
    final map = <int, double>{};
    for (final s in _spese) {
      final quote = _ripartisciPerMese(s, anno);
      quote.forEach((mese, quota) {
        map[mese] = (map[mese] ?? 0) + quota;
      });
    }
    return map;
  }

  /// Mappa categoriaId -> importo di competenza per l'anno dato
  Map<int, double> totalePerCategoriaCompetenza(int anno) {
    final map = <int, double>{};
    for (final s in _spese) {
      final quote = _ripartisciPerMese(s, anno);
      final totaleSpesa = quote.values.fold(0.0, (a, b) => a + b);
      if (totaleSpesa > 0) {
        map[s.categoriaId] = (map[s.categoriaId] ?? 0) + totaleSpesa;
      }
    }
    return map;
  }

  // Kept for compatibility
  Map<int, double> get totalePerCategoria =>
      totalePerCategoriaCompetenza(DateTime.now().year);

  Map<int, double> get totalePerMese =>
      totalePerMeseCompetenza(DateTime.now().year);

  List<int> get anniDisponibili {
    final anni = _spese.map((s) => s.data.year).toSet().toList();
    anni.sort((a, b) => b.compareTo(a));
    return anni;
  }

  // ---- BACKUP ----

  Future<void> exportBackup() async {
    final data = await DatabaseHelper.instance.exportData();
    final json = jsonEncode(data);
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName =
        'casa_spese_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], text: 'Backup Casa Spese');
  }

  Future<bool> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return false;
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      await DatabaseHelper.instance.importData(data);
      await loadAll();
      return true;
    } catch (e) {
      _error = 'Errore importazione: $e';
      notifyListeners();
      return false;
    }
  }
}
