import 'package:flutter/widgets.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/app/app_scope.dart';
import 'package:knotes/core/mvvm/view_model.dart';

abstract class ViewModelState<W extends StatefulWidget, V extends ViewModel>
    extends State<W> {
  late final V model = createViewModel(AppScope.read(context));
  V createViewModel(AppDependencies dependencies);
  @override
  void initState() {
    super.initState();
    model.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    onViewModelChanged();
  }

  void onViewModelChanged() {}
  @override
  void dispose() {
    model.removeListener(_changed);
    model.dispose();
    super.dispose();
  }
}
