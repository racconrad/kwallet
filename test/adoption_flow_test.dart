import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/app/app_scope.dart';
import 'package:knotes/core/database/database_service.dart';
import 'package:knotes/core/services/device_files.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';
import 'package:knotes/core/widgets/pet_loading_screen.dart';
import 'package:knotes/features/welcome/presentation/widgets/adoption_box.dart';
import 'package:knotes/features/welcome/presentation/launch_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets(
    'Box adoption preserves choices and saves only explicitly configured data',
    (tester) async {
      await initializeDateFormatting('es');
      if (const bool.fromEnvironment('KNOTES_CAPTURE')) {
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
          KnotesTheme.configure({'theme_mode': mode}, Brightness.light);
          final key = GlobalKey();
          await tester.pumpWidget(
            AppScope(
              dependencies: dependencies,
              child: MaterialApp(
                theme: KnotesTheme.expressiveTheme,
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
          for (
            var i = 0;
            i < 20 && find.byType(PetLoadingScreen).evaluate().isNotEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump();
          }
          await tester.pumpAndSettle();
          Future<void> capture(String page) async {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 60)),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
            if (!const bool.fromEnvironment('KNOTES_CAPTURE')) return;
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

          Future<void> tap(String label) async {
            await tester.ensureVisible(find.text(label).last);
            await tester.tap(find.text(label).last);
            await tester.pumpAndSettle();
          }

          Future<void> fill(String label, String text) async {
            final field = find.widgetWithText(TextField, label);
            await tester.ensureVisible(field);
            await tester.enterText(field, text);
            tester.testTextInput.hide();
            await tester.pumpAndSettle();
          }

          expect(find.text('Hay alguien\nesperándote.'), findsOneWidget);
          expect(find.byType(KittyCompanionWidget), findsNothing);
          await capture('box');
          await tester.tap(find.byType(AdoptionBox));
          await tester.pumpAndSettle();
          expect(find.byType(KittyCompanionWidget), findsOneWidget);
          await capture('reveal');
          await tap('Darle un nombre');
          await fill('Su nombre', 'Nube');
          await tap('Personalización avanzada');
          await tester.ensureVisible(find.byTooltip('Zarigüeya'));
          await tester.tap(find.byTooltip('Zarigüeya'));
          await tester.pumpAndSettle();
          await tap('Cerrar personalización');
          await capture('name');
          await tap('Continuar con Nube');
          expect(find.textContaining('tres áreas'), findsOneWidget);
          await capture('guide');
          await tap('Entendido');
          await capture('path');
          await tap('Empezar el recorrido');
          await tap('Añadir mi moneda');
          await fill('Símbolo', 'C\$');
          await fill('Nombre', 'Mi córdoba');
          await tester.tap(find.widgetWithText(FilledButton, 'Añadir moneda'));
          await tester.pumpAndSettle();
          await capture('currency');
          await tap('Usar C\$');
          await fill('Nombre de la cuenta', 'Mi bolsillo');
          await fill('Saldo inicial', '250.50');
          await capture('account');
          for (var i = 0; i < 3; i++) {
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }
          expect(find.textContaining('tres áreas'), findsOneWidget);
          await tap('Entendido');
          await tap('Empezar el recorrido');
          await tap('Usar C\$');
          expect(find.widgetWithText(TextField, 'Mi bolsillo'), findsOneWidget);
          await tap('Continuar con mi cuenta');
          await fill('Nombre del gasto', 'Mi café');
          await fill('Importe', '3.5');
          await fill('Categoría', 'Mis pausas');
          await tap('Añadir gasto hormiga');
          await capture('expenses');
          await tap('Continuar');
          await fill('Mi hábito', 'Leer por la tarde');
          await tap('Añadir hábito');
          await capture('habits');
          await tap('Continuar');
          await fill('Mi nota', 'Compras\n- pan\n- leche');
          await tap('Añadir nota');
          await capture('notes');
          await tap('Revisar y empezar');
          expect(find.text('Bienvenido a casa,\nNube.'), findsOneWidget);
          final before = await tester.runAsync(db.getAccounts);
          expect(before, isEmpty);
          await capture('home');
          await tap('Empezar juntos');
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
          final settings = await tester.runAsync(db.getSettings);
          expect(settings!['pet_style'], 'opossum_classic');
          expect(settings['pet_name'], 'Nube');
          expect(settings['currency'], 'C\$');
          expect(settings['notifications_enabled'], 'false');
          expect(settings['welcome_seen'], '1');
          expect(await tester.runAsync(db.getUserCurrencies), {
            'C\$': 'Mi córdoba',
          });
          expect(await tester.runAsync(db.getCurrencyRates), isEmpty);
          final accounts = await tester.runAsync(db.getAccounts);
          expect(accounts!.single.name, 'Mi bolsillo');
          final notes = await tester.runAsync(db.getNotes);
          expect(notes!.single.title, 'Compras');
          expect(notes.single.items.map((i) => i.text), ['pan', 'leche']);
          expect(accounts.single.balance, 250.50);
          expect(accounts.single.currency, 'C\$');
          expect(
            (await tester.runAsync(db.getQuickExpenses))!.single.title,
            'Mi café',
          );
          expect(
            (await tester.runAsync(db.getHabits))!.single.title,
            'Leer por la tarde',
          );
          expect(await tester.runAsync(db.getTransactions), isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(db.closeAndReset);
        }
      }
      KnotesTheme.configure({'theme_mode': 'light'}, Brightness.light);
    },
  );
  testWidgets(
    'Skipping setup enters without creating currencies, accounts or examples',
    (tester) async {
      await initializeDateFormatting('es');
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
      await tester.pumpWidget(
        AppScope(
          dependencies: dependencies,
          child: MaterialApp(
            theme: KnotesTheme.expressiveTheme,
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: LaunchScreen(),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String text) async {
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
      }

      await tap('Abrir la caja');
      await tap('Darle un nombre');
      await tester.enterText(
        find.widgetWithText(TextField, 'Su nombre'),
        'Terra',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tap('Continuar con Terra');
      await tap('Entendido');
      await tester.ensureVisible(find.text('Inicio rápido · 1 minuto'));
      await tap('Inicio rápido · 1 minuto');
      await tap('Empezar rápido');
      await tap('Omitir por ahora');
      await tap('Omitir por ahora');
      expect(find.text('Lo demás, a tu ritmo'), findsOneWidget);
      await tap('Empezar juntos');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect((await tester.runAsync(db.getSettings))!['welcome_seen'], '1');
      expect(await tester.runAsync(db.getUserCurrencies), isEmpty);
      expect(await tester.runAsync(db.getAccounts), isEmpty);
      expect(await tester.runAsync(db.getQuickExpenses), isEmpty);
      expect(await tester.runAsync(db.getHabits), isEmpty);
      expect(await tester.runAsync(db.getNotes), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(db.closeAndReset);
    },
  );
}
