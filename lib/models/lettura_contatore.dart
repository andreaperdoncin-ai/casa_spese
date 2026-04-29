// lib/models/lettura_contatore.dart

enum TipoContatore {
  riscaldamento,
  raffrescamento,
  acquaFredda,
  acquaCalda;

  String get nome {
    switch (this) {
      case TipoContatore.riscaldamento:  return 'Riscaldamento';
      case TipoContatore.raffrescamento: return 'Raffrescamento';
      case TipoContatore.acquaFredda:    return 'Acqua Fredda Sanitaria';
      case TipoContatore.acquaCalda:     return 'Acqua Calda Sanitaria';
    }
  }

  String get nomeBreve {
    switch (this) {
      case TipoContatore.riscaldamento:  return 'Risc.';
      case TipoContatore.raffrescamento: return 'Raffr.';
      case TipoContatore.acquaFredda:    return 'AFS';
      case TipoContatore.acquaCalda:     return 'ACS';
    }
  }

  String get unitaMisura {
    switch (this) {
      case TipoContatore.riscaldamento:
      case TipoContatore.raffrescamento: return 'MWh';
      case TipoContatore.acquaFredda:
      case TipoContatore.acquaCalda:     return 'm³';
    }
  }

  bool get isAcqua {
    return this == TipoContatore.acquaFredda || this == TipoContatore.acquaCalda;
  }

  String get dbValue {
    switch (this) {
      case TipoContatore.riscaldamento:  return 'riscaldamento';
      case TipoContatore.raffrescamento: return 'raffrescamento';
      case TipoContatore.acquaFredda:    return 'acqua_fredda';
      case TipoContatore.acquaCalda:     return 'acqua_calda';
    }
  }

  static TipoContatore fromDb(String value) {
    switch (value) {
      case 'riscaldamento':  return TipoContatore.riscaldamento;
      case 'raffrescamento': return TipoContatore.raffrescamento;
      case 'acqua_fredda':   return TipoContatore.acquaFredda;
      case 'acqua_calda':    return TipoContatore.acquaCalda;
      default:               return TipoContatore.riscaldamento;
    }
  }
}

class LetturaContatore {
  final int? id;
  final TipoContatore tipo;
  final DateTime data;
  final double valore; // MWh oppure m³, sempre con 3 decimali
  final String? note;

  LetturaContatore({
    this.id,
    required this.tipo,
    required this.data,
    required this.valore,
    this.note,
  });

  factory LetturaContatore.fromMap(Map<String, dynamic> map) {
    return LetturaContatore(
      id:     map['id'] as int?,
      tipo:   TipoContatore.fromDb(map['tipo'] as String),
      data:   DateTime.parse(map['data'] as String),
      valore: (map['valore'] as num).toDouble(),
      note:   map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'tipo':   tipo.dbValue,
      'data':   data.toIso8601String().split('T')[0],
      'valore': valore,
      'note':   note,
    };
    if (id != null) m['id'] = id;
    return m;
  }

  LetturaContatore copyWith({
    int? id,
    TipoContatore? tipo,
    DateTime? data,
    double? valore,
    String? note,
  }) {
    return LetturaContatore(
      id:     id ?? this.id,
      tipo:   tipo ?? this.tipo,
      data:   data ?? this.data,
      valore: valore ?? this.valore,
      note:   note ?? this.note,
    );
  }
}
