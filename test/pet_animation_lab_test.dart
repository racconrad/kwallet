import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knotes/core/models/pet_species.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';
import 'package:knotes/core/widgets/pet_atlas_painter.dart';
import 'package:knotes/features/pets/presentation/pet_animation_lab.dart';

Future<void> mountLab(
  WidgetTester tester, {
  Size size = const Size(1440, 1080),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const PetAnimationLab(),
    ),
  );
  // Cached atlas futures notify FutureBuilder in the real setUpAll zone.
  await tester.runAsync(() async {});
  await tester.pump();
}

void expectNativeSprites(WidgetTester tester) {
  final sprites = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is PetAtlasPainter,
  );
  expect(sprites, findsNWidgets(60));
  for (final element in sprites.evaluate()) {
    final size = tester.getSize(find.byWidget(element.widget));
    expect(size.width, greaterThanOrEqualTo(64));
    expect(size.width % 64, 0);
    expect(size.height, size.width);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => Future.wait([
      for (final species in PetSpecies.values)
        for (final xp in [0, 200])
          KittyCompanionWidget.loadAtlas(
            PetSpeciesCatalog.resolveAsset(
              PetSpeciesCatalog.forSpecies(species).first.key,
              xp: xp,
            ),
          ),
    ]),
  );

  testWidgets('Shows every catalog style and stage in exactly 64 grid slots', (
    tester,
  ) async {
    await mountLab(tester);
    final grid = tester.widget<GridView>(find.byType(GridView));
    final layout =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(layout.crossAxisCount, 8);
    expect(grid.childrenDelegate.estimatedChildCount, 64);
    for (final style in PetSpeciesCatalog.styles.values) {
      for (final stage in PetGrowthStage.values) {
        expect(
          find.byKey(ValueKey('${style.key}/${stage.name}')),
          findsOneWidget,
        );
      }
    }
    expect(find.text('60 pets · 8 × 8'), findsOneWidget);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<PetAtlasPainter>()
        .first;
    expect(painter.atlas, isNotNull);
    expect(painter.source, const Rect.fromLTWH(0, 0, 64, 64));
    expectNativeSprites(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Plays, pauses, steps, changes animations and changes contrast', (
    tester,
  ) async {
    await mountLab(tester);
    final dropdown = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    );
    expect(
      dropdown.items!.map((item) => item.value),
      orderedEquals([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
    );
    expect(find.text('Frame 1 / 8'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('Frame 2 / 8'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 480));
    expect(find.text('Frame 2 / 8'), findsOneWidget);
    await tester.tap(find.byTooltip('Next frame'));
    await tester.pump();
    expect(find.text('Frame 3 / 8'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    expect(find.text('Groom'), findsWidgets);
    expect(find.text('Stretch'), findsWidgets);
    await tester.tap(find.text('Run').last);
    await tester.pumpAndSettle();
    expect(find.text('Frame 1 / 8'), findsOneWidget);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.text('Frame 2 / 8'), findsOneWidget);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<PetAtlasPainter>()
        .first;
    expect(painter.source, const Rect.fromLTWH(64, 320, 64, 64));
    await tester.tap(find.byTooltip('Dark background'));
    await tester.pump();
    expect(find.byTooltip('Light background'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Keeps eight columns without overflow in a small desktop window',
    (tester) async {
      await mountLab(tester, size: const Size(640, 480));
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Keeps native-size sprites and labels at large text scale', (
    tester,
  ) async {
    await mountLab(tester, size: const Size(640, 480), textScale: 2);
    expect(tester.takeException(), isNull);
    expectNativeSprites(tester);
    await tester.pumpWidget(const SizedBox());
  });
}
