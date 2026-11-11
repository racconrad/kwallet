import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/journal/view_models/note_view_model.dart';
import 'package:knotes/features/journal/presentation/widgets/note_appearance_picker.dart';
import 'package:knotes/core/widgets/menu_label.dart';

Future<void> openNote(
  BuildContext context, {
  PersonalNote? note,
  String? initialKind,
  bool edit = false,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) =>
        NoteScreen(note: note, initialKind: initialKind, edit: edit),
  ),
);

class NoteScreen extends StatefulWidget {
  final PersonalNote? note;
  final String? initialKind;
  final bool edit;
  const NoteScreen({super.key, this.note, this.initialKind, this.edit = false});
  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _EditableNoteItem {
  final String id;
  final TextEditingController text;
  final FocusNode focus = FocusNode();
  bool done;
  DateTime? dueDate;
  _EditableNoteItem(NoteItem item)
    : id = item.id ?? const Uuid().v4(),
      text = TextEditingController(text: item.text),
      done = item.done,
      dueDate = item.dueDate;
  NoteItem get value =>
      NoteItem(text.text, id: id, done: done, dueDate: dueDate);
  void dispose() {
    text.dispose();
    focus.dispose();
  }
}

class _NoteScreenState extends ViewModelState<NoteScreen, NoteViewModel> {
  @override
  NoteViewModel createViewModel(AppDependencies dependencies) =>
      NoteViewModel(dependencies.journal, widget.note);
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _items = <_EditableNoteItem>[];
  final _retired = <_EditableNoteItem>[];
  late bool _editing = widget.note == null || widget.edit;
  late String _kind = widget.note?.kind ?? widget.initialKind ?? 'note';
  String _iconKey = 'note';
  int _colorValue = 0;
  bool _allowPop = false;
  String _baseline = '';
  String get _snapshot => jsonEncode([
    _title.text,
    _body.text,
    _iconKey,
    _colorValue,
    _items.map((i) => i.value.toMap()).toList(),
  ]);
  bool get _dirty => _snapshot != _baseline;
  Color get _color =>
      _colorValue == 0 ? KnotesTheme.accent : Color(_colorValue);

  @override
  void initState() {
    super.initState();
    _resetDraft(widget.note);
    if (widget.note == null && widget.initialKind == 'list') {
      _items.add(
        _EditableNoteItem(const NoteItem(''))..text.addListener(_draftChanged),
      );
      _baseline = _snapshot;
    }
    _title.addListener(_draftChanged);
    _body.addListener(_draftChanged);
  }

  void _draftChanged() {
    if (mounted && _editing) setState(() {});
  }

  void _resetDraft(PersonalNote? note) {
    _retired.addAll(_items);
    _items.clear();
    _title.text = note?.title ?? '';
    _body.text = note?.body ?? '';
    _iconKey = note?.iconKey ?? 'note';
    _colorValue = note?.colorValue ?? 0;
    _kind = note?.kind ?? widget.initialKind ?? 'note';
    for (final item in note?.items ?? <NoteItem>[]) {
      _items.add(_EditableNoteItem(item)..text.addListener(_draftChanged));
    }
    _baseline = _snapshot;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    for (final item in [..._items, ..._retired]) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    if (model.busy) return;
    if (_editing && _dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Descartar los cambios?'),
          content: const Text('Los cambios sin guardar se perderán.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await model.saveNote(
      original: model.original,
      title: _title.text,
      body: _body.text,
      kind: _items.any((item) => item.text.text.trim().isNotEmpty)
          ? 'list'
          : _kind,
      items: _items.map((item) => item.value),
      iconKey: _iconKey,
      colorValue: _colorValue,
    );
    if (!mounted || !saved) return;
    await model.load();
    if (!mounted) return;
    setState(() {
      _editing = false;
      _resetDraft(model.note);
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Nota guardada')));
  }

  Future<void> _check(int index, bool done) async {
    final note = model.note;
    if (note == null) return;
    if (await model.checkNote(note, index, done)) {
      HapticFeedback.selectionClick();
      await model.load();
    }
  }

  void _addItem([int? after]) {
    if (model.busy) return;
    final item = _EditableNoteItem(const NoteItem(''))
      ..text.addListener(_draftChanged);
    setState(
      () => _items.insert(after == null ? _items.length : after + 1, item),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      item.focus.requestFocus();
      final target = item.focus.context;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .55,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
        );
      }
    });
  }

  Future<void> _chooseAppearance() async {
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (_) =>
          NoteAppearancePicker(iconKey: _iconKey, colorValue: _colorValue),
    );
    if (result != null && mounted) {
      setState(() {
        _iconKey = result.$1;
        _colorValue = result.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = model.note;
    return PopScope(
      canPop: _allowPop || (!model.busy && (!_editing || !_dirty)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _close),
          title: Text(_editing ? (note == null ? 'Nueva' : 'Editar') : 'Nota'),
          actions: [
            if (!model.missing)
              _editing
                  ? TextButton(
                      onPressed: model.busy ? null : _save,
                      child: Text(model.busy ? 'Guardando…' : 'Guardar'),
                    )
                  : TextButton.icon(
                      onPressed: model.busy
                          ? null
                          : () => setState(() {
                              _resetDraft(note);
                              _editing = true;
                            }),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: model.missing
              ? const Center(child: Text('Esta nota ya no está disponible.'))
              : ContentWidth(
                  width: 720,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (model.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              model.error!,
                              style: TextStyle(color: KnotesTheme.expenseRed),
                              semanticsLabel: model.error,
                            ),
                          ),
                        if (_editing)
                          ..._editor(context)
                        else if (note != null)
                          ..._reader(context, note),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _reader(BuildContext context, PersonalNote note) {
    final done = note.items.where((i) => i.done).length;
    final color = note.colorValue == 0
        ? KnotesTheme.accent
        : Color(note.colorValue);
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Icon(getNoteIcon(note.iconKey), color: color, size: 28),
      ),
      const SizedBox(height: 12),
      SelectableText(
        note.title,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      if (note.body.isNotEmpty) ...[
        const SizedBox(height: 16),
        SelectableText(
          note.body,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
      ],
      if (note.items.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(
          '$done de ${note.items.length} completados',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < note.items.length; i++)
          CheckboxListTile(
            key: ValueKey('read-item-${note.items[i].id}'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            controlAffinity: ListTileControlAffinity.leading,
            value: note.items[i].done,
            title: Text(
              note.items[i].text,
              style: TextStyle(
                decoration: note.items[i].done
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: note.items[i].dueDate == null
                ? null
                : Text(
                    DateFormat('d MMM y', 'es').format(note.items[i].dueDate!),
                  ),
            onChanged: model.busy ? null : (done) => _check(i, done!),
          ),
      ],
      const SizedBox(height: 24),
      Text(
        'Actualizada el ${DateFormat('d MMM y', 'es').format(note.updatedAt)}',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: KnotesTheme.textSecondary),
      ),
    ];
  }

  List<Widget> _editor(BuildContext context) => [
    Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: model.busy ? null : _chooseAppearance,
        icon: Icon(getNoteIcon(_iconKey), color: _color),
        label: const Text('Icono y color'),
      ),
    ),
    const SizedBox(height: 20),
    TextField(
      key: const ValueKey('note-title'),
      controller: _title,
      enabled: !model.busy,
      textCapitalization: TextCapitalization.sentences,
      maxLines: null,
      style: Theme.of(context).textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700),
      decoration: const InputDecoration(
        hintText: 'Título',
        labelText: 'Título',
        alignLabelWithHint: true,
      ),
    ),
    const SizedBox(height: 16),
    TextField(
      key: const ValueKey('note-body'),
      controller: _body,
      enabled: !model.busy,
      textCapitalization: TextCapitalization.sentences,
      keyboardType: TextInputType.multiline,
      minLines: 4,
      maxLines: null,
      decoration: const InputDecoration(
        hintText: 'Escribe aquí…',
        labelText: 'Nota',
        alignLabelWithHint: true,
      ),
    ),
    if (_items.isNotEmpty) ...[
      const SizedBox(height: 24),
      Text('Lista', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        '5 XP por elemento · 20 XP al terminar',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: KnotesTheme.textSecondary),
      ),
      const SizedBox(height: 12),
      for (final item in _items) _itemEditor(item),
    ],
    const SizedBox(height: 8),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: model.busy ? null : () => _addItem(),
        icon: Icon(
          _items.isEmpty ? Icons.playlist_add_rounded : Icons.add_rounded,
        ),
        label: Text(_items.isEmpty ? 'Agregar lista' : 'Agregar elemento'),
      ),
    ),
  ];

  Widget _itemEditor(_EditableNoteItem item) => Padding(
    key: ValueKey(item.id),
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: item.done,
          onChanged: model.busy
              ? null
              : (value) => setState(() => item.done = value!),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): () =>
                      _addItem(_items.indexOf(item)),
                },
                child: TextField(
                  controller: item.text,
                  focusNode: item.focus,
                  enabled: !model.busy,
                  maxLines: null,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onEditingComplete: () {},
                  onSubmitted: (_) => _addItem(_items.indexOf(item)),
                  decoration: const InputDecoration(
                    hintText: 'Un pendiente…',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              if (item.dueDate != null)
                Text(
                  DateFormat('d MMM y', 'es').format(item.dueDate!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Opciones del elemento',
          enabled: !model.busy,
          onSelected: (value) async {
            if (value == 'delete') {
              setState(() {
                _items.remove(item);
                _retired.add(item);
              });
            } else if (value == 'clear') {
              setState(() => item.dueDate = null);
            } else {
              final picked = await showDatePicker(
                context: context,
                initialDate: item.dueDate ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
              );
              if (picked != null && mounted) {
                setState(() => item.dueDate = picked);
              }
            }
          },
          itemBuilder: (_) => [
            menuItem('date', Icons.event_outlined, 'Fecha límite'),
            if (item.dueDate != null)
              menuItem('clear', Icons.event_busy_outlined, 'Quitar fecha'),
            menuItem(
              'delete',
              Icons.delete_outline_rounded,
              'Quitar elemento',
              danger: true,
            ),
          ],
        ),
      ],
    ),
  );
}
