import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kwall/app/app_dependencies.dart';
import 'package:kwall/app/app_scope.dart';
import 'package:kwall/core/database/database_service.dart';
import 'package:kwall/core/services/device_files.dart';
import 'package:kwall/core/theme/kwall_theme.dart';
import 'package:kwall/core/widgets/currency_selector.dart';
import 'package:kwall/features/welcome/presentation/launch_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets(
    'Adoption keeps chosen pet and name, greets, selects currency and starts together',
    (tester) async {
      await initializeDateFormatting('es');
      if (const bool.fromEnvironment('KWALL_CAPTURE')) {
        await tester.runAsync(() async {
          final config = File('.dart_tool/package_config.json').absolute;
          final packages =
              (jsonDecode(await config.readAsString()) as Map)['packages']
                  as List;
          final flutter =
              packages.firstWhere((p) => p['name'] == 'flutter') as Map;
          final root = Directory.fromUri(
            config.uri.resolve(flutter['rootUri'] as String),
          ).parent.parent.path;
          for (final entry in {
            'Roboto': 'Roboto-Regular.ttf',
            'MaterialIcons': 'MaterialIcons-Regular.otf',
          }.entries) {
            final loader = FontLoader(entry.key);
            loader.addFont(
              File('$root/bin/cache/artifacts/material_fonts/${entry.value}')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            );
            await loader.load();
          }
        });
      }
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [
        const Size(390, 844),
        const Size(1024, 900),
        const Size(320, 740),
      ]) {
        for (final mode in ['light', 'dark']) {
          final db = DatabaseService.atPath(
            inMemoryDatabasePath,
            factory: databaseFactoryFfiNoIsolate,
          );
          final dependencies = AppDependencies(
            finance: db,
            journal: db,
            settings: db,
            files: NativeDeviceFiles(),
          );
          tester.view.physicalSize = size;
          KwallTheme.configure({'theme_mode': mode}, Brightness.light);
          final key = GlobalKey();
          await tester.pumpWidget(
            AppScope(
              dependencies: dependencies,
              child: MaterialApp(
                theme: KwallTheme.expressiveTheme,
                home: RepaintBoundary(
                  key: key,
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      disableAnimations: true,
                      textScaler: TextScaler.linear(
                        size.width == 320 ? 1.3 : 1,
                      ),
                    ),
                    child: const LaunchScreen(),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();
          Future<void> capture(String page) async {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 60)),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
            if (!const bool.fromEnvironment('KWALL_CAPTURE')) return;
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '.impeccable/review/welcome-$page-${size.width.toInt()}-$mode.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }

          expect(find.text('Hay alguien\nesperándote.'), findsOneWidget);
          expect(find.textContaining('XP'), findsNothing);
          await capture('meet');
          await tester.tap(find.text('Quiero conocerle'));
          await tester.pumpAndSettle();
          expect(find.text('¿Quién va contigo?'), findsOneWidget);
          await tester.tap(find.byTooltip('Zarigüeya'));
          await tester.pumpAndSettle();
          await capture('choose');
          await tester.tap(find.text('Este va conmigo'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).first, 'Nube');
          await tester.pumpAndSettle();
          tester.testTextInput.hide();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byTooltip('Acariciar a Nube').first);
          await tester.tap(find.byTooltip('Acariciar a Nube').first);
          await tester.pumpAndSettle();
          expect(find.text('Ya te reconoce.'), findsOneWidget);
          await capture('name');
          await tester.tap(find.text('Me gusta su nombre'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(CurrencySelector));
          await tester.tap(find.byType(CurrencySelector));
          await tester.pumpAndSettle();
          await tester.tap(find.text('C\$ Córdoba').last);
          await tester.pumpAndSettle();
          await capture('days');
          // Native back retains all choices.
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('Un nombre.\nUn nuevo amigo.'), findsOneWidget);
          expect(find.widgetWithText(TextField, 'Nube'), findsOneWidget);
          await tester.tap(find.text('Me gusta su nombre'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Todo listo'));
          await tester.pumpAndSettle();
          expect(find.text('Bienvenido a casa,\nNube.'), findsOneWidget);
          await capture('home');
          await tester.tap(find.text('Empezar juntos'));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 500));
          final settings = await tester.runAsync(db.getSettings);
          expect(settings!['pet_style'], 'opossum_classic');
          expect(settings['pet_name'], 'Nube');
          expect(settings['currency'], 'NIO');
          expect(settings['notifications_enabled'], 'false');
          expect(settings['welcome_seen'], '1');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(db.closeAndReset);
        }
      }
      KwallTheme.configure({'theme_mode': 'light'}, Brightness.light);
    },
  );
}
