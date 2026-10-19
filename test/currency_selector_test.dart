import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwall/app/app_dependencies.dart';
import 'package:kwall/app/app_scope.dart';
import 'package:kwall/core/database/database_service.dart';
import 'package:kwall/core/theme/kwall_theme.dart';
import 'package:kwall/core/services/device_files.dart';
import 'package:kwall/core/widgets/currency_selector.dart';
import 'package:kwall/features/bodega/presentation/add_account_dialog.dart';
import 'package:kwall/features/bodega/view_models/account_editor_view_model.dart';
import 'package:kwall/features/welcome/view_models/launch_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets(
    'Account currency selection works without text input on compact and wide screens',
    (tester) async {
      sqfliteFfiInit();
      final service = DatabaseService.atPath(
        inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate,
      );
      await tester.runAsync(() async {
        await service.saveUserCurrency('USD', 'Dólar estadounidense');
        await service.saveUserCurrency('NIO', 'Córdoba');
        await service.setCurrencyRate(currency: 'NIO', rate: 0.025);
        if (const bool.fromEnvironment('KWALL_CAPTURE')) {
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
        }
      });
      addTearDown(() async => (await service.database).close());
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final key = GlobalKey();
      for (final size in [const Size(390, 844), const Size(1024, 900)]) {
        for (final mode in ['light', 'dark']) {
          await tester.pumpWidget(const SizedBox.shrink());
          tester.view.physicalSize = size;
          KwallTheme.configure({'theme_mode': mode}, Brightness.light);
          await tester.pumpWidget(
            AppScope(
              dependencies: AppDependencies(
                finance: service,
                journal: service,
                settings: service,
                files: NativeDeviceFiles(),
              ),
              child: MaterialApp(
                theme: KwallTheme.expressiveTheme,
                home: RepaintBoundary(
                  key: key,
                  child: const Scaffold(
                    body: AddAccountDialog(currency: 'USD'),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();
          expect(find.byType(CurrencySelector), findsOneWidget);
          expect(
            find.text('Moneda principal en la que opera esta cuenta.'),
            findsNothing,
          );
          await tester.tap(find.byType(CurrencySelector));
          await tester.pumpAndSettle();
          await tester.tap(find.text('C\$ Córdoba').last);
          await tester.pumpAndSettle();
          final field = tester.widget<DropdownButtonFormField<String>>(
            find.descendant(
              of: find.byType(CurrencySelector),
              matching: find.byType(DropdownButtonFormField<String>),
            ),
          );
          expect(field.initialValue, 'NIO');
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('KWALL_CAPTURE')) {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '.impeccable/review/account-${size.width.toInt()}-$mode.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      }
      KwallTheme.configure({'theme_mode': 'light'}, Brightness.light);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'CurrencySelector shows only provided options and formats optional name',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrencySelector(
              value: 'EUR',
              options: const ['EUR', 'MXN', 'BTC'],
              currencyNames: const {
                'EUR': 'Euro',
                // 'MXN' has no name
                'BTC': 'Bitcoin',
              },
              onChanged: (val) => selected = val,
            ),
          ),
        ),
      );

      // Initial value is € Euro
      expect(find.text('€ Euro'), findsOneWidget);

      // Open dropdown
      await tester.tap(find.byType(CurrencySelector));
      await tester.pumpAndSettle();

      // Options exist
      expect(find.text('€ Euro'), findsWidgets);
      expect(
        find.text('MX\$ Peso mexicano'),
        findsOneWidget,
      ); // name was omitted, shows only symbol
      expect(find.text('₿ Bitcoin'), findsOneWidget);

      // Hardcoded catalog currencies (e.g. JPY, CHF, etc.) are NOT present
      expect(find.text('JPY'), findsNothing);
      expect(find.text('CHF'), findsNothing);

      // Select MXN
      await tester.tap(find.text('MX\$ Peso mexicano').last);
      await tester.pumpAndSettle();
      expect(selected, 'MXN');
    },
  );

  test(
    'Database persists user currencies with symbol and optional name',
    () async {
      sqfliteFfiInit();
      final service = DatabaseService.atPath(
        inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate,
      );
      addTearDown(() async => (await service.database).close());

      // Initial user currencies have default currency '$'
      final initial = await service.getUserCurrencies();
      expect(initial.containsKey('\$'), isTrue);

      // Save custom currencies: one with name, one without
      await service.saveUserCurrency('EUR', 'Euro');
      await service.saveUserCurrency('L'); // Lempira, name omitted

      final updated = await service.getUserCurrencies();
      expect(updated['EUR'], 'Euro');
      expect(updated['L'], '');

      // Delete custom currency
      await service.deleteUserCurrency('L');
      final afterDelete = await service.getUserCurrencies();
      expect(afterDelete.containsKey('L'), isFalse);
      expect(afterDelete.containsKey('EUR'), isTrue);
    },
  );

  test('Auto theme (system) is default in KwallTheme', () {
    KwallTheme.configure({}, Brightness.light);
    expect(KwallTheme.mode, 'system');
    expect(KwallTheme.isDark, isFalse);

    KwallTheme.configure({}, Brightness.dark);
    expect(KwallTheme.mode, 'system');
    expect(KwallTheme.isDark, isTrue);
  });

  test(
    'LaunchViewModel saves primary and secondary currencies to user_currencies',
    () async {
      sqfliteFfiInit();
      final service = DatabaseService.atPath(
        inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate,
      );
      addTearDown(() async => (await service.database).close());

      final launchModel = LaunchViewModel(service);
      final ok = await launchModel.enter(
        petStyle: 'classic',
        petName: 'Mishi',
        currency: 'USD',
        currencyName: 'Dólar',
        referenceCurrencies: 'EUR,CAD',
        userCurrencies: {
          'USD': 'Dólar',
          'EUR': 'Euro',
          'CAD': 'Dólar Canadiense',
        },
      );
      expect(ok, isTrue);

      final currencies = await service.getUserCurrencies();
      expect(currencies['USD'], 'Dólar');
      expect(currencies['EUR'], 'Euro');
      expect(currencies['CAD'], 'Dólar Canadiense');
      // Ensure no other currencies exist besides what the user defined
      expect(currencies.containsKey('\$'), isFalse);
      expect(currencies.length, 3);

      // AccountEditorViewModel loads all these currencies and ONLY these into currencyOptions
      final editorModel = AccountEditorViewModel(service, service);
      await editorModel.loadCurrencies();
      expect(editorModel.currencyOptions, equals(['CAD', 'EUR', 'USD']));
      expect(editorModel.currencyNames['EUR'], 'Euro');
    },
  );
}
