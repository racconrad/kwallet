import 'package:flutter/material.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/journal/view_models/journal_actions_view_model.dart';

/// Saves a note or checklist from one text box; shared by Home and Mi espacio.
class QuickCaptureField extends StatefulWidget {
  const QuickCaptureField({super.key});
  @override
  State<QuickCaptureField> createState() => _QuickCaptureFieldState();
}

class _QuickCaptureFieldState
    extends ViewModelState<QuickCaptureField, JournalActionsViewModel> {
  @override
  JournalActionsViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.journalActions();
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await model.quickNote(_text.text);
    if (!mounted) return;
    if (saved) {
      _text.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Guardado en tus notas.')));
    } else {
      showFailure(context, model.error ?? 'No se pudo guardar.');
    }
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    minLines: 1,
    maxLines: 4,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      labelText: 'Anotar rápido',
      hintText: 'Compras\n- pan\n- leche',
      helperText: 'La primera línea es el título; las que empiezan con «-» se vuelven tareas.',
      helperMaxLines: 2,
      suffixIcon: IconButton(
        tooltip: 'Guardar nota',
        onPressed: model.busy ? null : _save,
        icon: const Icon(Icons.send_rounded),
      ),
    ),
  );
}
