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

  // ---- STATISTICHE ----

  double get totaleAnnoCorrente {
    final anno = DateTime.now().year;
    return _spese
        .where((s) => s.data.year == anno)
        .fold(0.0, (sum, s) => sum + s.importo);
  }

  double get mediaMensileAnnoCorrente {
    return totaleAnnoCorrente / 12;
  }

  Map<int, double> get totalePerCategoria {
    final anno = DateTime.now().year;
    final map = <int, double>{};
    for (final s in _spese.where((s) => s.data.year == anno)) {
      map[s.categoriaId] = (map[s.categoriaId] ?? 0) + s.importo;
    }
    return map;
  }

  Map<int, double> get totalePerMese {
    final anno = DateTime.now().year;
    final map = <int, double>{};
    for (final s in _spese.where((s) => s.data.year == anno)) {
      map[s.data.month] = (map[s.data.month] ?? 0) + s.importo;
    }
    return map;
  }

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
