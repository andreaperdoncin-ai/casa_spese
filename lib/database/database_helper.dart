// lib/database/database_helper.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/spesa.dart';
import '../models/categoria.dart';
import '../models/lettura_contatore.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'casa_spese.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ---- CREAZIONE DB (installazione nuova) ----

  Future<void> _onCreate(Database db, int version) async {
    await _createTableCategorie(db);
    await _createTableSpese(db);
    await _createTableLettureContatori(db);
    await _insertCategoriePredefinite(db);
  }

  // ---- MIGRAZIONE (aggiornamento da v1 a v2) ----

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTableLettureContatori(db);
    }
  }

  // ---- DEFINIZIONI TABELLE ----

  Future<void> _createTableCategorie(Database db) async {
    await db.execute('''
      CREATE TABLE categorie (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        nome      TEXT    NOT NULL,
        icona     TEXT    NOT NULL,
        colore    INTEGER NOT NULL,
        predefinita INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createTableSpese(Database db) async {
    await db.execute('''
      CREATE TABLE spese (
        id               TEXT PRIMARY KEY,
        categoria_id     INTEGER NOT NULL,
        importo          REAL    NOT NULL,
        data             TEXT    NOT NULL,
        competenza_inizio TEXT,
        competenza_fine  TEXT,
        note             TEXT,
        kwh              REAL,
        canone_rai       REAL,
        FOREIGN KEY (categoria_id) REFERENCES categorie(id)
      )
    ''');
  }

  Future<void> _createTableLettureContatori(Database db) async {
    await db.execute('''
      CREATE TABLE letture_contatori (
        id     INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo   TEXT    NOT NULL,
        data   TEXT    NOT NULL,
        valore REAL    NOT NULL,
        note   TEXT
      )
    ''');
  }

  Future<void> _insertCategoriePredefinite(Database db) async {
    final categoriePredefinite = [
      {'nome': 'Condominio',  'icona': 'apartment',         'colore': 0xFF1565C0, 'predefinita': 1},
      {'nome': 'Elettricità', 'icona': 'bolt',              'colore': 0xFFF57F17, 'predefinita': 1},
      {'nome': 'Internet',    'icona': 'wifi',              'colore': 0xFF2E7D32, 'predefinita': 1},
      {'nome': 'TARI',        'icona': 'delete_outline',    'colore': 0xFF6A1B9A, 'predefinita': 1},
      {'nome': 'Assicurazioni','icona': 'shield',           'colore': 0xFFB71C1C, 'predefinita': 1},
      {'nome': 'Pulizie',     'icona': 'cleaning_services', 'colore': 0xFF00695C, 'predefinita': 1},
    ];
    for (final cat in categoriePredefinite) {
      await db.insert('categorie', cat);
    }
  }

  // ---- CATEGORIE ----

  Future<List<Categoria>> getCategorie() async {
    final db = await database;
    final maps = await db.query('categorie', orderBy: 'predefinita DESC, nome ASC');
    return maps.map((m) => Categoria.fromMap(m)).toList();
  }

  Future<int> insertCategoria(Categoria cat) async {
    final db = await database;
    return await db.insert('categorie', cat.toMap());
  }

  Future<void> deleteCategoria(int id) async {
    final db = await database;
    await db.delete('categorie', where: 'id = ?', whereArgs: [id]);
  }

  // ---- SPESE ----

  Future<List<Spesa>> getSpese() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT s.*, c.nome as cat_nome, c.icona as cat_icona, c.colore as cat_colore
      FROM spese s
      JOIN categorie c ON s.categoria_id = c.id
      ORDER BY s.data DESC
    ''');
    return maps.map((m) => Spesa.fromMap(m)).toList();
  }

  Future<String> insertSpesa(Spesa spesa) async {
    final db = await database;
    await db.insert('spese', spesa.toMap());
    return spesa.id;
  }

  Future<void> insertSpeseBatch(List<Spesa> spese) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final s in spese) {
        await txn.insert('spese', s.toMap());
      }
    });
  }

  Future<void> updateSpesa(Spesa spesa) async {
    final db = await database;
    await db.update('spese', spesa.toMap(), where: 'id = ?', whereArgs: [spesa.id]);
  }

  Future<void> deleteSpesa(String id) async {
    final db = await database;
    await db.delete('spese', where: 'id = ?', whereArgs: [id]);
  }

  // ---- LETTURE CONTATORI ----

  Future<List<LetturaContatore>> getLettureContatori() async {
    final db = await database;
    final maps = await db.query(
      'letture_contatori',
      orderBy: 'tipo ASC, data DESC',
    );
    return maps.map((m) => LetturaContatore.fromMap(m)).toList();
  }

  Future<int> insertLetturaContatore(LetturaContatore lettura) async {
    final db = await database;
    return await db.insert('letture_contatori', lettura.toMap());
  }

  Future<void> updateLetturaContatore(LetturaContatore lettura) async {
    final db = await database;
    await db.update(
      'letture_contatori',
      lettura.toMap(),
      where: 'id = ?',
      whereArgs: [lettura.id],
    );
  }

  Future<void> deleteLetturaContatore(int id) async {
    final db = await database;
    await db.delete('letture_contatori', where: 'id = ?', whereArgs: [id]);
  }

  // ---- BACKUP ----

  Future<Map<String, dynamic>> exportData() async {
    final db = await database;
    final categorie        = await db.query('categorie');
    final spese            = await db.query('spese');
    final lettureContatori = await db.query('letture_contatori');
    return {
      'version':            2,
      'exported_at':        DateTime.now().toIso8601String(),
      'categorie':          categorie,
      'spese':              spese,
      'letture_contatori':  lettureContatori,
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('spese');
      await txn.delete('categorie');
      await txn.delete('letture_contatori');
      for (final cat in (data['categorie'] as List)) {
        await txn.insert('categorie', Map<String, dynamic>.from(cat));
      }
      for (final spesa in (data['spese'] as List)) {
        await txn.insert('spese', Map<String, dynamic>.from(spesa));
      }
      // Compatibile con backup v1 (senza letture contatori)
      if (data.containsKey('letture_contatori')) {
        for (final l in (data['letture_contatori'] as List)) {
          await txn.insert('letture_contatori', Map<String, dynamic>.from(l));
        }
      }
    });
  }
}
