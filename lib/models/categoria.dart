import 'package:flutter/material.dart';

class Categoria {
  final int? id;
  final String nome;
  final String icona;
  final int colore;
  final bool predefinita;

  Categoria({
    this.id,
    required this.nome,
    required this.icona,
    required this.colore,
    this.predefinita = false,
  });

  Color get color => Color(colore);

  IconData get iconData {
    const map = {
      'apartment': Icons.apartment,
      'bolt': Icons.bolt,
      'wifi': Icons.wifi,
      'delete_outline': Icons.delete_outline,
      'shield': Icons.shield,
      'cleaning_services': Icons.cleaning_services,
      'category': Icons.category,
    };
    return map[icona] ?? Icons.category;
  }

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      icona: map['icona'] as String,
      colore: map['colore'] as int,
      predefinita: (map['predefinita'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'nome': nome,
      'icona': icona,
      'colore': colore,
      'predefinita': predefinita ? 1 : 0,
    };
    if (id != null) m['id'] = id;
    return m;
  }

  Categoria copyWith({int? id, String? nome, String? icona, int? colore, bool? predefinita}) {
    return Categoria(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      icona: icona ?? this.icona,
      colore: colore ?? this.colore,
      predefinita: predefinita ?? this.predefinita,
    );
  }
}
