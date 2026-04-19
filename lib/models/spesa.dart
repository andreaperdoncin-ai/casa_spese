import 'categoria.dart';

class Spesa {
  final String id;
  final int categoriaId;
  final double importo;
  final DateTime data;
  final DateTime? competenzaInizio;
  final DateTime? competenzaFine;
  final String? note;
  // Solo per Elettricità
  final double? kwh;
  final double? canoneRai;
  // Join fields (non salvati nel DB)
  final String? catNome;
  final String? catIcona;
  final int? catColore;

  Spesa({
    required this.id,
    required this.categoriaId,
    required this.importo,
    required this.data,
    this.competenzaInizio,
    this.competenzaFine,
    this.note,
    this.kwh,
    this.canoneRai,
    this.catNome,
    this.catIcona,
    this.catColore,
  });

  factory Spesa.fromMap(Map<String, dynamic> map) {
    return Spesa(
      id: map['id'] as String,
      categoriaId: map['categoria_id'] as int,
      importo: (map['importo'] as num).toDouble(),
      data: DateTime.parse(map['data'] as String),
      competenzaInizio: map['competenza_inizio'] != null
          ? DateTime.parse(map['competenza_inizio'] as String)
          : null,
      competenzaFine: map['competenza_fine'] != null
          ? DateTime.parse(map['competenza_fine'] as String)
          : null,
      note: map['note'] as String?,
      kwh: map['kwh'] != null ? (map['kwh'] as num).toDouble() : null,
      canoneRai: map['canone_rai'] != null ? (map['canone_rai'] as num).toDouble() : null,
      catNome: map['cat_nome'] as String?,
      catIcona: map['cat_icona'] as String?,
      catColore: map['cat_colore'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoria_id': categoriaId,
      'importo': importo,
      'data': data.toIso8601String().split('T')[0],
      'competenza_inizio': competenzaInizio?.toIso8601String().split('T')[0],
      'competenza_fine': competenzaFine?.toIso8601String().split('T')[0],
      'note': note,
      'kwh': kwh,
      'canone_rai': canoneRai,
    };
  }

  Spesa copyWith({
    String? id,
    int? categoriaId,
    double? importo,
    DateTime? data,
    DateTime? competenzaInizio,
    DateTime? competenzaFine,
    String? note,
    double? kwh,
    double? canoneRai,
  }) {
    return Spesa(
      id: id ?? this.id,
      categoriaId: categoriaId ?? this.categoriaId,
      importo: importo ?? this.importo,
      data: data ?? this.data,
      competenzaInizio: competenzaInizio ?? this.competenzaInizio,
      competenzaFine: competenzaFine ?? this.competenzaFine,
      note: note ?? this.note,
      kwh: kwh ?? this.kwh,
      canoneRai: canoneRai ?? this.canoneRai,
      catNome: catNome,
      catIcona: catIcona,
      catColore: catColore,
    );
  }
}
