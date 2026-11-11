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
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/journal/presentation/note_screen.dart';
import 'package:knotes/features/journal/view_models/journal_actions_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseService db;
  setUp(() {
    db = DatabaseService.atPath(
      inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    );
  });
  tearDown(() => db.closeAndReset());
  PersonalNote note({List<NoteItem> items = const [], String kind = 'note'}) =>
      PersonalNote(
        id: 'note',
        title: 'Preparar la semana',
        body: 'Ideas para empezar con calma.\nLo esencial, a mano.',
        kind: kind,
        items: items,
        updatedAt: DateTime(2026, 10, 19),
      );

  test('Checklist XP is atomic and awarded once across toggles, edits, reorder and backup', () async {
    await db.saveNote(
      note(
        items: [
          NoteItem('Comprar fruta', dueDate: DateTime(2026, 10, 24)),
          const NoteItem('Revisar agenda'),
        ],
      ),
    );
    expect(await db.getExperience(), 0);
    expect(await db.getFrontPendingItems(), hasLength(2));
    await db.setNoteItem('note', 0, true, expectedText: 'Comprar fruta');
    await db.setNoteItem('note', 0, true, expectedText: 'Comprar fruta');
    expect(await db.getExperience(), 5);
    await db.setNoteItem('note', 1, true, expectedText: 'Revisar agenda');
    expect(await db.getExperience(), 30);
    await db.setNoteItem('note', 0, false, expectedText: 'Comprar fruta');
    await db.setNoteItem('note', 0, true, expectedText: 'Comprar fruta');
    final stored = (await db.getNotes()).single;
    expect(stored.items.first.dueDate, DateTime(2026, 10, 24));
    final vm = JournalActionsViewModel(db);
    addTearDown(vm.dispose);
    expect(
      await vm.saveNote(
        original: stored,
        title: stored.title,
        body: stored.body,
        kind: 'note',
        items: [
          stored.items.last,
          NoteItem(
            'Fruta y pan',
            id: stored.items.first.id,
            done: true,
            dueDate: stored.items.first.dueDate,
          ),
        ],
      ),
      isTrue,
    );
    expect(await db.getExperience(), 30);
    var reordered = (await db.getNotes()).single;
    expect(reordered.items.last.dueDate, DateTime(2026, 10, 24));
    expect(
      await vm.saveNote(
        original: reordered,
        title: reordered.title,
        body: reordered.body,
        kind: 'note',
        items: [...reordered.items, const NoteItem('Llamar', done: true)],
      ),
      isTrue,
    );
    expect(await db.getExperience(), 35);
    final backup = await db.exportFullDataAsJson();
    await db.importFullDataFromJson(backup);
    reordered = (await db.getNotes()).single;
    await db.setNoteItem('note', 2, false, expectedText: 'Llamar');
    await db.setNoteItem('note', 2, true, expectedText: 'Llamar');
    expect(await db.getExperience(), 35);
    expect(reordered.items.map((i) => i.id).toSet(), hasLength(3));
    await expectLater(
      db.setNoteItem('note', 0, false, expectedText: 'stale'),
      throwsStateError,
    );
    expect(await db.getExperience(), 35);
  });

  test('Legacy items receive stable identities and preserve dates without a schema migration', () async {
    final database = await db.database;
    await database.insert(
      'personal_notes',
      note(
        items: [
          NoteItem('Uno', dueDate: DateTime(2026, 11, 1)),
          const NoteItem('Dos'),
        ],
      ).toMap(),
    );
    final first = (await db.getNotes()).single;
    expect(first.items.first.id, 'legacy:note:0');
    await db.setNoteItem('note', 0, true, expectedText: 'Uno');
    await db.setNoteItem('note', 0, false, expectedText: 'Uno');
    await db.setNoteItem('note', 0, true, expectedText: 'Uno');
    expect(await db.getExperience(), 5);
    expect(
      (await db.getNotes()).single.items.first.dueDate,
      DateTime(2026, 11, 1),
    );
    await db.saveNote(
      note(items: const [NoteItem('Uno', done: true), NoteItem('Dos')]),
    );
    expect((await db.getNotes()).single.items.first.id, first.items.first.id);
    expect(await db.getExperience(), 5);
    await db.setNoteItem('note', 1, true, expectedText: 'Dos');
    expect(await db.getExperience(), 30);
  });

  test('Duplicate item IDs roll back note and reward changes', () async {
    await db.saveNote(note());
    await expectLater(
      db.saveNote(
        note(
          items: const [
            NoteItem('A', id: 'same', done: true),
            NoteItem('B', id: 'same', done: true),
          ],
        ),
      ),
      throwsArgumentError,
    );
    expect((await db.getNotes()).single.items, isEmpty);
    expect(await db.getExperience(), 0);
  });

  Future<void> settle(
    WidgetTester tester, [
    Future<void> Function()? action,
  ]) async {
    await tester.runAsync(() async {
      if (action != null) await action();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester tester, {
    PersonalNote? value,
    bool edit = false,
    Size size = const Size(390, 844),
    String mode = 'light',
    double scale = 1,
    GlobalKey? capture,
  }) async {
    await initializeDateFormatting('es');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    KnotesTheme.configure({'theme_mode': mode}, Brightness.light);
    await tester.pumpWidget(
      AppScope(
        dependencies: AppDependencies(
          finance: db,
          journal: db,
          settings: db,
          files: NativeDeviceFiles(),
        ),
        child: MaterialApp(
          theme: KnotesTheme.expressiveTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(
              key: const ValueKey('notes-capture'),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openNote(context, note: value, edit: edit),
                child: const Text('Abrir nota'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir nota'));
    await settle(tester);
  }

  setUp(() {
    addTearDown(
      () => KnotesTheme.configure({'theme_mode': 'light'}, Brightness.light),
    );
  });

  testWidgets(
    'Notes open full screen in compact read mode and persist checks without editing',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => db.saveNote(
          note(
            items: const [
              NoteItem('Comprar fruta'),
              NoteItem('Revisar agenda'),
            ],
          ),
        ),
      );
      final stored = await tester.runAsync(
        () async => (await db.getNotes()).single,
      );
      await mount(tester, value: stored);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Editar'), findsOneWidget);
      expect(tester.getSize(find.byType(NoteScreen)), const Size(390, 844));
      await settle(
        tester,
        () => tester.tap(find.byType(CheckboxListTile).first),
      );
      expect(find.text('1 de 2 completados'), findsOneWidget);
      expect(await tester.runAsync(db.getExperience), 5);
      await settle(
        tester,
        () => tester.tap(find.byType(CheckboxListTile).last),
      );
      expect(await tester.runAsync(db.getExperience), 30);
    },
  );

  testWidgets(
    'Editor adds a list to plain text, Enter inserts and focuses next item, appearance and save survive reopening',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester);
      await tester.enterText(
        find.byKey(const ValueKey('note-title')),
        'Mi día',
      );
      await tester.enterText(
        find.byKey(const ValueKey('note-body')),
        'Una idea que quiero conservar.',
      );
      await tester.ensureVisible(find.text('Agregar lista'));
      await tester.tap(find.text('Agregar lista'));
      await tester.pumpAndSettle();
      var fields = find.byType(TextField);
      await tester.enterText(fields.at(2), 'Primero');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      fields = find.byType(TextField);
      expect(fields, findsNWidgets(4));
      expect(tester.widget<TextField>(fields.last).focusNode!.hasFocus, isTrue);
      await tester.enterText(fields.last, 'Segundo');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(5));
      await tester.ensureVisible(find.text('Icono y color'));
      await tester.tap(find.text('Icono y color'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar icono'),
        'Compras',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Compras'));
      await tester.tap(find.byTooltip('Azul'));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      await settle(tester, () => tester.tap(find.text('Guardar')));
      expect(find.byType(TextField), findsNothing);
      final saved = await tester.runAsync(
        () async => (await db.getNotes()).single,
      );
      expect(saved!.body, 'Una idea que quiero conservar.');
      expect(saved.items.map((i) => i.text), ['Primero', 'Segundo']);
      expect(saved.iconKey, 'shopping');
      expect(saved.colorValue, 0xFF3B82F6);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note-body')))
            .controller!
            .text,
        saved.body,
      );
      expect(find.text('Primero'), findsOneWidget);
      await tester.ensureVisible(find.text('Primero'));
      await tester.tap(find.text('Primero'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(5));
      expect(
        tester
            .widget<TextField>(find.byType(TextField).at(3))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(
        find.byKey(const ValueKey('note-title')),
        'Sin guardar',
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteScreen), findsOneWidget);
      expect(
        (await tester.runAsync(() async => (await db.getNotes()).single))!
            .title,
        'Mi día',
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteScreen), findsNothing);
      await mount(tester, value: saved);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Mi día'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Read editor and icon picker fit compact tablet light dark and large text layouts',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => db.saveNote(
          note(
            items: [
              const NoteItem('Comprar fruta para la semana'),
              NoteItem(
                'Revisar agenda y preparar documentos',
                dueDate: DateTime(2026, 10, 24),
              ),
              const NoteItem('Reservar un momento para leer', done: true),
            ],
          ),
        ),
      );
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
            final loader = FontLoader(entry.key)
              ..addFont(
                File('$root/bin/cache/artifacts/material_fonts/${entry.value}')
                    .readAsBytes()
                    .then(ByteData.sublistView),
              );
            await loader.load();
          }
        });
      }
      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment('KNOTES_CAPTURE')) return;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('notes-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('.impeccable/review/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      for (final size in [const Size(320, 740), const Size(1024, 900)]) {
        for (final mode in ['light', 'dark']) {
          await tester.pumpWidget(const SizedBox.shrink());
          final stored = await tester.runAsync(
            () async => (await db.getNotes()).single,
          );
          await mount(
            tester,
            value: stored,
            size: size,
            mode: mode,
            scale: size.width == 320 ? 1.3 : 1,
          );
          await capture('notes-read-${size.width.toInt()}-$mode');
          await tester.tap(find.text('Editar'));
          await tester.pumpAndSettle();
          await capture('notes-edit-${size.width.toInt()}-$mode');
          await tester.ensureVisible(find.text('Agregar elemento'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Icono y color'));
          await tester.tap(find.text('Icono y color'));
          await tester.pumpAndSettle();
          await capture('notes-icons-${size.width.toInt()}-$mode');
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
