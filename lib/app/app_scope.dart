import 'package:flutter/widgets.dart';

import 'package:knotes/app/app_dependencies.dart';

class AppScope extends InheritedWidget {
  final AppDependencies dependencies;
  const AppScope({super.key, required this.dependencies, required super.child});
  static AppDependencies read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.dependencies;
  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
