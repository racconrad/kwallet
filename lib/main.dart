import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/app/app_scope.dart';
import 'package:knotes/app/app_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/welcome/presentation/launch_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KnotesApp());
}

class KnotesApp extends StatefulWidget {
  final AppDependencies? dependencies;
  const KnotesApp({super.key, this.dependencies});
  @override
  State<KnotesApp> createState() => _KnotesAppState();
}

class _KnotesAppState extends State<KnotesApp> with WidgetsBindingObserver {
  late final _dependencies = widget.dependencies ?? AppDependencies.local();
  late final AppViewModel _model = _dependencies.app();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _model.addListener(_appearance);
    _appearance();
  }

  void _appearance() {
    KnotesTheme.configure(
      _model.settings,
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  @override
  void didChangePlatformBrightness() => _appearance();
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _model.removeListener(_appearance);
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: KnotesTheme.revision,
    builder: (_, value, child) => AppScope(
      dependencies: _dependencies,
      child: MaterialApp(
        title: 'knotes',
        debugShowCheckedModeBanner: false,
        theme: KnotesTheme.expressiveTheme,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => AnimatedTheme(
          data: KnotesTheme.expressiveTheme,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const LaunchScreen(),
      ),
    ),
  );
}
