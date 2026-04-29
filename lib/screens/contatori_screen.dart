// lib/screens/contatori_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/lettura_contatore.dart';

// ============================================================
//  SCHERMATA PRINCIPALE
// ============================================================

class ContatoriScreen extends StatefulWidget {
  const ContatoriScreen({super.key});

  @override
  State<ContatoriScreen> createState() => _ContatoriScreenState();
}

class _ContatoriScreenState extends State<ContatoriScreen> {
  TipoContatore? _tipoSelezionato;
  List<LetturaContatore> _letture = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLetture();
  }

  Future<void> _loadLetture() async {
    setState(() => _loading = true);
    final letture = await DatabaseHelper.instance.getLettureContatori();
    setState(() {
      _letture = letture;
      _loading = false;
    });
  }

  List<LetturaContatore> get _lettureOrdinate {
    final lista = [..._letture];
    lista.sort((a, b) => b.data.compareTo(a.data));
    return lista;
  }

  List<LetturaContatore> _letturePerTipo(TipoContatore tipo) {
    final lista = _letture.where((l) => l.tipo == tipo).toList();
    lista.sort((a, b) => b.data.compareTo(a.data));
    return lista;
  }

  void _apriFormNuovaLettura() async {
    final risultato = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _FormLetturaScreen(
          tipoPreselezionato: _tipoSelezionato,
          onSave: (lettura) async {
            await DatabaseHelper.instance.insertLetturaContatore(lettura);
          },
        ),
      ),
    );
    if (risultato == true) await _loadLetture();
  }

  void _apriFormModifica(LetturaContatore lettura) async {
    final risultato = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _FormLetturaScreen(
          letturaEsistente: lettura,
          onSave: (l) async {
            await DatabaseHelper.instance.updateLetturaContatore(l);
          },
        ),
      ),
    );
    if (risultato == true) await _loadLetture();
  }

  Future<void> _eliminaLettura(LetturaContatore lettura) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina lettura'),
        content: Text(
          'Eliminare la lettura del ${DateFormat('d MMM yyyy', 'it_IT').format(lettura.data)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (conferma == true) {
      await DatabaseHelper.instance.deleteLetturaContatore(lettura.id!);
      await _loadLetture();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contatori'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Selettore contatori
                _SelettoreContatori(
                  tipoSelezionato: _tipoSelezionato,
                  onSelected: (tipo) => setState(() {
                    // Toccare lo stesso contatore lo deseleziona
                    _tipoSelezionato = _tipoSelezionato == tipo ? null : tipo;
                  }),
                ),
                const Divider(height: 1),
                // Contenuto
                Expanded(
                  child: _tipoSelezionato == null
                      ? _ListaGlobale(
                          letture: _lettureOrdinate,
                          tutteLetture: _letture,
                          onModifica: _apriFormModifica,
                          onElimina: _eliminaLettura,
                        )
                      : _ContenutoContatore(
                          tipo: _tipoSelezionato!,
                          letture: _letturePerTipo(_tipoSelezionato!),
                          onModifica: _apriFormModifica,
                          onElimina: _eliminaLettura,
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _apriFormNuovaLettura,
        icon: const Icon(Icons.add),
        label: const Text('Nuova lettura'),
      ),
    );
  }
}

// ============================================================
//  SELETTORE CONTATORI (4 card in cima)
// ============================================================

class _SelettoreContatori extends StatelessWidget {
  final TipoContatore? tipoSelezionato;
  final void Function(TipoContatore) onSelected;

  const _SelettoreContatori({
    required this.tipoSelezionato,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: TipoContatore.values.map((tipo) {
          final selezionato = tipo == tipoSelezionato;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _CardContatore(
                tipo: tipo,
                selezionato: selezionato,
                onTap: () => onSelected(tipo),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CardContatore extends StatelessWidget {
  final TipoContatore tipo;
  final bool selezionato;
  final VoidCallback onTap;

  const _CardContatore({
    required this.tipo,
    required this.selezionato,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme    = Theme.of(context).colorScheme;
    final coloreAttivo   = colorScheme.primary;
    final coloreInattivo = Colors.grey[400]!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selezionato ? coloreAttivo.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selezionato ? coloreAttivo : Colors.grey[300]!,
            width: selezionato ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconaTipo(tipo),
              size: 24,
              color: selezionato ? coloreAttivo : coloreInattivo,
            ),
            const SizedBox(height: 4),
            Text(
              tipo.nomeBreve,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selezionato ? FontWeight.w700 : FontWeight.normal,
                color: selezionato ? coloreAttivo : coloreInattivo,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconaTipo(TipoContatore t) {
    switch (t) {
      case TipoContatore.riscaldamento:  return Icons.thermostat;
      case TipoContatore.raffrescamento: return Icons.ac_unit;
      case TipoContatore.acquaFredda:    return Icons.water_drop_outlined;
      case TipoContatore.acquaCalda:     return Icons.water_drop;
    }
  }
}

// ============================================================
//  LISTA GLOBALE (nessun contatore selezionato)
// ============================================================

class _ListaGlobale extends StatelessWidget {
  final List<LetturaContatore> letture;       // tutte, ordinate DESC per data
  final List<LetturaContatore> tutteLetture;  // tutte, non ordinate (per calcolo precedente)
  final void Function(LetturaContatore) onModifica;
  final void Function(LetturaContatore) onElimina;

  const _ListaGlobale({
    required this.letture,
    required this.tutteLetture,
    required this.onModifica,
    required this.onElimina,
  });

  // Trova la lettura precedente dello stesso tipo (la più recente prima di questa)
  LetturaContatore? _precedente(LetturaContatore lettura) {
    final stessoTipo = tutteLetture
        .where((l) => l.tipo == lettura.tipo && l.data.isBefore(lettura.data))
        .toList();
    if (stessoTipo.isEmpty) return null;
    stessoTipo.sort((a, b) => b.data.compareTo(a.data));
    return stessoTipo.first;
  }

  @override
  Widget build(BuildContext context) {
    if (letture.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Nessuna lettura inserita',
                style: TextStyle(fontSize: 16, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('Tocca + per aggiungere la prima',
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: letture.map((lettura) {
        return _LetturaCard(
          lettura:    lettura,
          precedente: _precedente(lettura),
          mostraTipo: true,
          onModifica: () => onModifica(lettura),
          onElimina:  () => onElimina(lettura),
        );
      }).toList(),
    );
  }
}

// ============================================================
//  CONTENUTO CONTATORE SELEZIONATO
// ============================================================

class _ContenutoContatore extends StatelessWidget {
  final TipoContatore tipo;
  final List<LetturaContatore> letture; // ordinate DESC
  final void Function(LetturaContatore) onModifica;
  final void Function(LetturaContatore) onElimina;

  const _ContenutoContatore({
    required this.tipo,
    required this.letture,
    required this.onModifica,
    required this.onElimina,
  });

  @override
  Widget build(BuildContext context) {
    if (letture.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Nessuna lettura per ${tipo.nomeBreve}',
                style: TextStyle(fontSize: 16, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('Tocca + per aggiungere la prima',
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        _StatisticheCard(tipo: tipo, letture: letture),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(
            'STORICO LETTURE',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
        ),
        ...letture.asMap().entries.map((entry) {
          final i          = entry.key;
          final lettura    = entry.value;
          final precedente = i + 1 < letture.length ? letture[i + 1] : null;
          return _LetturaCard(
            lettura:    lettura,
            precedente: precedente,
            mostraTipo: false,
            onModifica: () => onModifica(lettura),
            onElimina:  () => onElimina(lettura),
          );
        }),
      ],
    );
  }
}

// ============================================================
//  CARD STATISTICHE
// ============================================================

class _StatisticheCard extends StatelessWidget {
  final TipoContatore tipo;
  final List<LetturaContatore> letture; // ordinate DESC

  const _StatisticheCard({required this.tipo, required this.letture});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ultima      = letture.first;
    final penultima   = letture.length > 1 ? letture[1] : null;
    final prima       = letture.last;

    // Periodo corrente
    final consumoPeriodo     = penultima != null ? (ultima.valore - penultima.valore) : null;
    final giorniPeriodo      = penultima != null
        ? ultima.data.difference(penultima.data).inDays
        : null;
    final giornalieroPeriodo =
        (consumoPeriodo != null && giorniPeriodo != null && giorniPeriodo > 0)
            ? consumoPeriodo / giorniPeriodo
            : null;

    // Totale complessivo
    final consumoTotale     = ultima.valore - prima.valore;
    final giorniTotali      = ultima.data.difference(prima.data).inDays;
    final giornalieroTotale = giorniTotali > 0 ? consumoTotale / giorniTotali : null;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      color: colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Ultima lettura
            _StatRow(
              label: 'Ultima lettura  (${DateFormat('d MMM yyyy', 'it_IT').format(ultima.data)})',
              value: '${_fmt3(ultima.valore)} ${tipo.unitaMisura}',
              evidenziato: true,
            ),

            // Periodo corrente
            if (penultima != null) ...[
              const Divider(height: 20),
              Text(
                'Periodo  ${DateFormat('d/M', 'it_IT').format(penultima.data)}'
                ' → ${DateFormat('d/M/yy', 'it_IT').format(ultima.data)}',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              _StatRow(
                label: 'Consumo',
                value: _formatConsumo(consumoPeriodo!, tipo),
              ),
              _StatRow(label: 'Giorni', value: '$giorniPeriodo gg'),
              if (giornalieroPeriodo != null)
                _StatRow(
                  label: 'Media giornaliera',
                  value: _formatGiornaliero(giornalieroPeriodo, tipo),
                  evidenziato: true,
                ),
            ],

            // Totale complessivo
            if (giorniTotali > 0) ...[
              const Divider(height: 20),
              const Text(
                'Totale dalla prima lettura',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              _StatRow(
                label: 'Consumo totale',
                value: _formatConsumo(consumoTotale, tipo),
              ),
              _StatRow(label: 'Giorni totali', value: '$giorniTotali gg'),
              if (giornalieroTotale != null)
                _StatRow(
                  label: 'Media giornaliera',
                  value: _formatGiornaliero(giornalieroTotale, tipo),
                  evidenziato: true,
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatConsumo(double v, TipoContatore t) {
    if (t.isAcqua) {
      // Litri senza decimali per ACS/AFS
      return '${_fmtL(v * 1000)} L  (${_fmt3(v)} m³)';
    }
    return '${_fmt3(v)} ${t.unitaMisura}';
  }

  String _formatGiornaliero(double v, TipoContatore t) {
    if (t.isAcqua) {
      // Litri/giorno senza decimali
      return '${_fmtL(v * 1000)} L/giorno';
    }
    return '${_fmt5(v)} ${t.unitaMisura}/giorno';
  }

  String _fmt3(double v)  => NumberFormat('#,##0.000', 'it_IT').format(v);
  String _fmt5(double v)  => NumberFormat('#,##0.00000', 'it_IT').format(v);
  String _fmtL(double v)  => NumberFormat('#,##0', 'it_IT').format(v.round());
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool evidenziato;

  const _StatRow({required this.label, required this.value, this.evidenziato = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: evidenziato ? FontWeight.bold : FontWeight.normal,
              color: evidenziato ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  CARD SINGOLA LETTURA
// ============================================================

class _LetturaCard extends StatelessWidget {
  final LetturaContatore lettura;
  final LetturaContatore? precedente;
  final bool mostraTipo; // true nella lista globale, false nello storico per tipo
  final VoidCallback onModifica;
  final VoidCallback onElimina;

  const _LetturaCard({
    required this.lettura,
    required this.precedente,
    required this.mostraTipo,
    required this.onModifica,
    required this.onElimina,
  });

  @override
  Widget build(BuildContext context) {
    final df  = DateFormat('d MMMM yyyy', 'it_IT');
    final fmt = NumberFormat('#,##0.000', 'it_IT');

    double? consumo;
    int? giorni;
    double? giornaliero;

    if (precedente != null) {
      consumo     = lettura.valore - precedente!.valore;
      giorni      = lettura.data.difference(precedente!.data).inDays;
      giornaliero = giorni > 0 ? consumo / giorni : null;
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onModifica,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icona tipo (solo nella lista globale)
              if (mostraTipo) ...[
                Icon(_iconaTipo(lettura.tipo),
                    size: 22, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nella lista globale mostra il nome del contatore
                    if (mostraTipo)
                      Text(lettura.tipo.nomeBreve,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600)),
                    Text(df.format(lettura.data),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      '${fmt.format(lettura.valore)} ${lettura.tipo.unitaMisura}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (consumo != null && giorni != null) ...[
                      const SizedBox(height: 4),
                      _ConsumoChip(
                        consumo:     consumo,
                        giorni:      giorni,
                        giornaliero: giornaliero,
                        tipo:        lettura.tipo,
                      ),
                    ],
                    if (lettura.note != null && lettura.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lettura.note!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'modifica') onModifica();
                  if (v == 'elimina') onElimina();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'modifica', child: Text('Modifica')),
                  const PopupMenuItem(
                    value: 'elimina',
                    child: Text('Elimina', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconaTipo(TipoContatore t) {
    switch (t) {
      case TipoContatore.riscaldamento:  return Icons.thermostat;
      case TipoContatore.raffrescamento: return Icons.ac_unit;
      case TipoContatore.acquaFredda:    return Icons.water_drop_outlined;
      case TipoContatore.acquaCalda:     return Icons.water_drop;
    }
  }
}

// ============================================================
//  CHIP CONSUMO (nelle card lettura)
// ============================================================

class _ConsumoChip extends StatelessWidget {
  final double consumo;
  final int giorni;
  final double? giornaliero;
  final TipoContatore tipo;

  const _ConsumoChip({
    required this.consumo,
    required this.giorni,
    required this.giornaliero,
    required this.tipo,
  });

  @override
  Widget build(BuildContext context) {
    final fmt3 = NumberFormat('#,##0.000', 'it_IT');
    final fmt5 = NumberFormat('#,##0.00000', 'it_IT');

    final String consumoStr;
    final String giornalieroStr;

    if (tipo.isAcqua) {
      // Litri senza decimali per ACS/AFS
      final litri           = (consumo * 1000).round();
      final litriGiorno     = giornaliero != null ? (giornaliero! * 1000).round() : null;
      consumoStr            = '+$litri L';
      giornalieroStr        = litriGiorno != null ? '$litriGiorno L/g' : '';
    } else {
      consumoStr     = '+${fmt3.format(consumo)} ${tipo.unitaMisura}';
      giornalieroStr = giornaliero != null
          ? '${fmt5.format(giornaliero!)} ${tipo.unitaMisura}/g'
          : '';
    }

    return Wrap(
      spacing: 6,
      children: [
        _Chip(text: consumoStr,   color: Colors.teal),
        _Chip(text: '$giorni gg', color: Colors.blueGrey),
        if (giornalieroStr.isNotEmpty)
          _Chip(text: giornalieroStr, color: Colors.indigo),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ============================================================
//  FORM INSERIMENTO / MODIFICA LETTURA
// ============================================================

class _FormLetturaScreen extends StatefulWidget {
  final TipoContatore? tipoPreselezionato;
  final LetturaContatore? letturaEsistente;
  final Future<void> Function(LetturaContatore) onSave;

  const _FormLetturaScreen({
    this.tipoPreselezionato,
    this.letturaEsistente,
    required this.onSave,
  });

  @override
  State<_FormLetturaScreen> createState() => _FormLetturaScreenState();
}

class _FormLetturaScreenState extends State<_FormLetturaScreen> {
  final _formKey          = GlobalKey<FormState>();
  final _valoreController = TextEditingController();
  final _noteController   = TextEditingController();

  late TipoContatore _tipoSelezionato;
  late DateTime _dataSelezionata;
  bool _saving = false;

  bool get _isModifica => widget.letturaEsistente != null;

  @override
  void initState() {
    super.initState();
    final existing   = widget.letturaEsistente;
    _tipoSelezionato = existing?.tipo ?? widget.tipoPreselezionato ?? TipoContatore.riscaldamento;
    _dataSelezionata = existing?.data ?? DateTime.now();

    if (existing != null) {
      _valoreController.text = NumberFormat('#,##0.000', 'it_IT').format(existing.valore);
      _noteController.text   = existing.note ?? '';
    }
  }

  @override
  void dispose() {
    _valoreController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selezionaData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelezionata,
      firstDate: DateTime(2024, 10, 31),
      lastDate: DateTime.now(),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) setState(() => _dataSelezionata = picked);
  }

  double? _parseValore(String text) {
    final normalized = text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _salva() async {
    if (!_formKey.currentState!.validate()) return;

    final valore = _parseValore(_valoreController.text);
    if (valore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valore non valido')),
      );
      return;
    }

    setState(() => _saving = true);

    final lettura = LetturaContatore(
      id:     widget.letturaEsistente?.id,
      tipo:   _tipoSelezionato,
      data:   _dataSelezionata,
      valore: valore,
      note:   _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    await widget.onSave(lettura);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMMM yyyy', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isModifica ? 'Modifica lettura' : 'Nuova lettura'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            TextButton(
              onPressed: _salva,
              child: const Text('Salva',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // Tipo contatore
            const Text('Contatore',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<TipoContatore>(
              value: _tipoSelezionato,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.speed_outlined)),
              items: TipoContatore.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.nome)))
                  .toList(),
              onChanged: (v) => setState(() => _tipoSelezionato = v!),
            ),
            const SizedBox(height: 20),

            // Data
            const Text('Data lettura',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selezionaData,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(df.format(_dataSelezionata),
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),

            // Valore
            Text(
              'Valore (${_tipoSelezionato.unitaMisura})',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _valoreController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.onetwothree_outlined),
                hintText: '0,000',
                suffixText: _tipoSelezionato.unitaMisura,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Inserisci il valore';
                if (_parseValore(v) == null) return 'Valore non valido (es. 1,234)';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Note
            const Text('Note (opzionale)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.notes_outlined),
                hintText: 'Eventuali annotazioni...',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
