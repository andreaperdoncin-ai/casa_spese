import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/spesa_provider.dart';
import '../models/spesa.dart';
import '../models/categoria.dart';

// Frequenze disponibili per spese ripetute
enum Frequenza {
  quindicinale('Ogni 2 settimane', 14),
  mensile('Mensile', 30),
  bimestrale('Bimestrale', 60),
  trimestrale('Trimestrale', 90),
  annuale('Annuale', 365);

  final String label;
  final int giorni; // usato solo come riferimento, la logica usa mesi/settimane

  const Frequenza(this.label, this.giorni);
}

class AggiungiSpesaScreen extends StatefulWidget {
  final Spesa? spesaDaModificare;
  const AggiungiSpesaScreen({super.key, this.spesaDaModificare});

  @override
  State<AggiungiSpesaScreen> createState() => _AggiungiSpesaScreenState();
}

class _AggiungiSpesaScreenState extends State<AggiungiSpesaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _importoCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _kwhCtrl = TextEditingController();
  final _canoneRaiCtrl = TextEditingController();

  DateTime _data = DateTime.now();
  DateTime? _competenzaInizio;
  DateTime? _competenzaFine;
  Categoria? _categoria;
  bool _isModifica = false;
  late String _spesaId;

  // Spese ripetute
  bool _isRipetuta = false;
  Frequenza _frequenza = Frequenza.mensile;
  int _numeroRipetizioni = 6; // quante occorrenze generare

  bool get _isElettricita =>
      _categoria?.nome.toLowerCase() == 'elettricità';

  // Categorie che supportano la ripetizione
  bool get _supportaRipetizione {
    final nome = _categoria?.nome.toLowerCase() ?? '';
    return nome == 'internet' || nome == 'pulizie';
  }

  // Frequenze disponibili per categoria
  List<Frequenza> get _frequenzeDisponibili {
    final nome = _categoria?.nome.toLowerCase() ?? '';
    if (nome == 'pulizie') {
      return [Frequenza.quindicinale, Frequenza.mensile, Frequenza.bimestrale];
    }
    return [
      Frequenza.mensile,
      Frequenza.bimestrale,
      Frequenza.trimestrale,
      Frequenza.annuale,
    ];
  }

  @override
  void initState() {
    super.initState();
    final s = widget.spesaDaModificare;
    if (s != null) {
      _isModifica = true;
      _spesaId = s.id;
      _data = s.data;
      _competenzaInizio = s.competenzaInizio;
      _competenzaFine = s.competenzaFine;
      _importoCtrl.text = s.importo.toStringAsFixed(2);
      _noteCtrl.text = s.note ?? '';
      _kwhCtrl.text = s.kwh?.toStringAsFixed(0) ?? '';
      _canoneRaiCtrl.text = s.canoneRai?.toStringAsFixed(2) ?? '';
    } else {
      _spesaId = const Uuid().v4();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_categoria == null) {
      final provider = context.read<SpesaProvider>();
      if (widget.spesaDaModificare != null) {
        _categoria =
            provider.getCategoriaById(widget.spesaDaModificare!.categoriaId);
      } else if (provider.categorie.isNotEmpty) {
        _categoria = provider.categorie.first;
      }
    }
  }

  @override
  void dispose() {
    _importoCtrl.dispose();
    _noteCtrl.dispose();
    _kwhCtrl.dispose();
    _canoneRaiCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) setState(() => _data = picked);
  }

  Future<void> _pickCompetenza() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _competenzaInizio != null && _competenzaFine != null
          ? DateTimeRange(start: _competenzaInizio!, end: _competenzaFine!)
          : null,
      locale: const Locale('it', 'IT'),
      helpText: 'Periodo di competenza',
      saveText: 'Conferma',
    );
    if (range != null) {
      setState(() {
        _competenzaInizio = range.start;
        _competenzaFine = range.end;
      });
    }
  }

  // Genera lista di date per le occorrenze ripetute
  List<DateTime> _generaDateRipetute() {
    final date = <DateTime>[];
    DateTime corrente = _data;

    for (int i = 0; i < _numeroRipetizioni; i++) {
      date.add(corrente);
      corrente = _avanzaData(corrente, _frequenza);
    }
    return date;
  }

  DateTime _avanzaData(DateTime data, Frequenza freq) {
    switch (freq) {
      case Frequenza.quindicinale:
        return data.add(const Duration(days: 14));
      case Frequenza.mensile:
        return DateTime(data.year, data.month + 1, data.day);
      case Frequenza.bimestrale:
        return DateTime(data.year, data.month + 2, data.day);
      case Frequenza.trimestrale:
        return DateTime(data.year, data.month + 3, data.day);
      case Frequenza.annuale:
        return DateTime(data.year + 1, data.month, data.day);
    }
  }

  // Genera la competenza per ogni occorrenza in base alla frequenza
  (DateTime, DateTime) _competenzaPerOccorrenza(DateTime dataOccorrenza) {
    // Se l'utente ha già impostato una competenza, la usiamo come base
    // e la spostiamo proporzionalmente
    if (_competenzaInizio != null && _competenzaFine != null) {
      final durata = _competenzaFine!.difference(_competenzaInizio!);
      final offset = dataOccorrenza.difference(_data);
      final nuovoInizio = _competenzaInizio!.add(offset);
      final nuovaFine = nuovoInizio.add(durata);
      return (nuovoInizio, nuovaFine);
    }
    // Altrimenti genera automaticamente in base alla frequenza
    switch (_frequenza) {
      case Frequenza.quindicinale:
        return (dataOccorrenza,
            dataOccorrenza.add(const Duration(days: 13)));
      case Frequenza.mensile:
        return (dataOccorrenza,
            DateTime(dataOccorrenza.year, dataOccorrenza.month + 1, dataOccorrenza.day - 1));
      case Frequenza.bimestrale:
        return (dataOccorrenza,
            DateTime(dataOccorrenza.year, dataOccorrenza.month + 2, dataOccorrenza.day - 1));
      case Frequenza.trimestrale:
        return (dataOccorrenza,
            DateTime(dataOccorrenza.year, dataOccorrenza.month + 3, dataOccorrenza.day - 1));
      case Frequenza.annuale:
        return (dataOccorrenza,
            DateTime(dataOccorrenza.year + 1, dataOccorrenza.month, dataOccorrenza.day - 1));
    }
  }

  Future<void> _salva() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoria == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona una categoria')),
      );
      return;
    }

    final importo =
        double.tryParse(_importoCtrl.text.replaceAll(',', '.')) ?? 0;
    final provider = context.read<SpesaProvider>();

    if (_isModifica) {
      // Modifica singola spesa
      final spesa = Spesa(
        id: _spesaId,
        categoriaId: _categoria!.id!,
        importo: importo,
        data: _data,
        competenzaInizio: _competenzaInizio,
        competenzaFine: _competenzaFine,
        note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        kwh: _isElettricita && _kwhCtrl.text.isNotEmpty
            ? double.tryParse(_kwhCtrl.text.replaceAll(',', '.'))
            : null,
        canoneRai: _isElettricita && _canoneRaiCtrl.text.isNotEmpty
            ? double.tryParse(_canoneRaiCtrl.text.replaceAll(',', '.'))
            : null,
      );
      await provider.updateSpesa(spesa);
    } else if (_isRipetuta && _supportaRipetizione) {
      // Inserimento multiplo
      final dateRipetute = _generaDateRipetute();
      for (final dataOcc in dateRipetute) {
        final comp = _competenzaPerOccorrenza(dataOcc);
        final spesa = Spesa(
          id: const Uuid().v4(),
          categoriaId: _categoria!.id!,
          importo: importo,
          data: dataOcc,
          competenzaInizio: comp.$1,
          competenzaFine: comp.$2,
          note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        );
        await provider.addSpesa(spesa);
      }
    } else {
      // Inserimento singolo
      final spesa = Spesa(
        id: _spesaId,
        categoriaId: _categoria!.id!,
        importo: importo,
        data: _data,
        competenzaInizio: _competenzaInizio,
        competenzaFine: _competenzaFine,
        note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        kwh: _isElettricita && _kwhCtrl.text.isNotEmpty
            ? double.tryParse(_kwhCtrl.text.replaceAll(',', '.'))
            : null,
        canoneRai: _isElettricita && _canoneRaiCtrl.text.isNotEmpty
            ? double.tryParse(_canoneRaiCtrl.text.replaceAll(',', '.'))
            : null,
      );
      await provider.addSpesa(spesa);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _elimina() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina spesa'),
        content: const Text('Confermi l\'eliminazione di questa spesa?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<SpesaProvider>().deleteSpesa(_spesaId);
      if (mounted) Navigator.pop(context);
    }
  }

  // Anteprima date che verranno generate
  void _mostraAnteprima() {
    final df = DateFormat('d MMM yyyy', 'it_IT');
    final date = _generaDateRipetute();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Occorrenze che verranno create'),
        content: SizedBox(
          width: 300,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: date.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final comp = _competenzaPerOccorrenza(date[i]);
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                ),
                title: Text(df.format(date[i])),
                subtitle: Text(
                  'Comp: ${df.format(comp.$1)} → ${df.format(comp.$2)}',
                  style: const TextStyle(fontSize: 11),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMMM yyyy', 'it_IT');
    final categorie = context.watch<SpesaProvider>().categorie;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isModifica ? 'Modifica spesa' : 'Nuova spesa'),
        actions: [
          if (_isModifica)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Elimina',
              onPressed: _elimina,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Categoria ----
            const _SectionLabel('Categoria'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categorie.map((cat) {
                final selected = _categoria?.id == cat.id;
                return ChoiceChip(
                  avatar: Icon(cat.iconData,
                      size: 16,
                      color: selected ? Colors.white : cat.color),
                  label: Text(cat.nome),
                  selected: selected,
                  selectedColor: cat.color,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : null,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() {
                    _categoria = cat;
                    _isRipetuta = false;
                    // Aggiusta frequenza se non disponibile nella nuova cat
                    if (!_frequenzeDisponibili.contains(_frequenza)) {
                      _frequenza = _frequenzeDisponibili.first;
                    }
                  }),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ---- Data ----
            const _SectionLabel('Data pagamento'),
            InkWell(
              onTap: _pickData,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(df.format(_data)),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Competenza (non mostrata se ripetuta, la calcola auto) ----
            if (!_isRipetuta) ...[
              const _SectionLabel('Periodo di competenza (opzionale)'),
              InkWell(
                onTap: _pickCompetenza,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.date_range_outlined),
                    suffixIcon: _competenzaInizio != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() {
                              _competenzaInizio = null;
                              _competenzaFine = null;
                            }),
                          )
                        : const Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    _competenzaInizio != null
                        ? '${df.format(_competenzaInizio!)} → ${df.format(_competenzaFine!)}'
                        : 'Seleziona periodo',
                    style: TextStyle(
                      color: _competenzaInizio == null
                          ? Colors.grey[500]
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ---- Importo ----
            const _SectionLabel('Importo (€)'),
            TextFormField(
              controller: _importoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))
              ],
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.euro_outlined),
                hintText: '0,00',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Inserisci un importo';
                final val = double.tryParse(v.replaceAll(',', '.'));
                if (val == null || val <= 0) return 'Importo non valido';
                return null;
              },
            ),

            // ---- Campi extra Elettricità ----
            if (_isElettricita) ...[
              const SizedBox(height: 16),
              const _SectionLabel('Dettagli elettricità'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _kwhCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Totale kWh',
                        prefixIcon: Icon(Icons.bolt_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _canoneRaiCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Canone RAI (€)',
                        prefixIcon: Icon(Icons.tv_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ---- Spese ripetute (solo per Internet e Pulizie, solo in inserimento) ----
            if (_supportaRipetizione && !_isModifica) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Spesa ripetuta',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        Text(
                          'Inserisci più occorrenze in una volta',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isRipetuta,
                    onChanged: (v) => setState(() => _isRipetuta = v),
                  ),
                ],
              ),
              if (_isRipetuta) ...[
                const SizedBox(height: 16),
                const _SectionLabel('Frequenza'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _frequenzeDisponibili.map((f) {
                    final selected = _frequenza == f;
                    return ChoiceChip(
                      label: Text(f.label),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _frequenza = f),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const _SectionLabel('Numero di occorrenze'),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _numeroRipetizioni > 2
                          ? () => setState(() => _numeroRipetizioni--)
                          : null,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '$_numeroRipetizioni',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            _descrizionePeriodo(),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _numeroRipetizioni < 36
                          ? () => setState(() => _numeroRipetizioni++)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Competenza con spese ripetute
                const _SectionLabel(
                    'Competenza prima occorrenza (opzionale)'),
                InkWell(
                  onTap: _pickCompetenza,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.date_range_outlined),
                      helperText:
                          'Le successive verranno calcolate automaticamente',
                      suffixIcon: _competenzaInizio != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() {
                                _competenzaInizio = null;
                                _competenzaFine = null;
                              }),
                            )
                          : const Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _competenzaInizio != null
                          ? '${DateFormat('d MMM yyyy', 'it_IT').format(_competenzaInizio!)} → ${DateFormat('d MMM yyyy', 'it_IT').format(_competenzaFine!)}'
                          : 'Seleziona periodo (auto se vuoto)',
                      style: TextStyle(
                        color: _competenzaInizio == null
                            ? Colors.grey[500]
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _mostraAnteprima,
                  icon: const Icon(Icons.preview_outlined),
                  label: const Text('Anteprima occorrenze'),
                ),
              ],
            ],

            const SizedBox(height: 16),

            // ---- Note ----
            const _SectionLabel('Note'),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Aggiungi una nota...',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.notes_outlined),
                ),
              ),
            ),

            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _salva,
              icon: Icon(_isRipetuta
                  ? Icons.playlist_add
                  : Icons.save_outlined),
              label: Text(_isModifica
                  ? 'Salva modifiche'
                  : _isRipetuta
                      ? 'Inserisci $_numeroRipetizioni occorrenze'
                      : 'Salva spesa'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _descrizionePeriodo() {
    final df = DateFormat('d MMM yyyy', 'it_IT');
    final date = _generaDateRipetute();
    if (date.isEmpty) return '';
    return '${df.format(date.first)} → ${df.format(date.last)}';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
