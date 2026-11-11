import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knotes/core/models/pet_species.dart';
import 'package:knotes/core/services/pet_atlas.dart';
import 'package:knotes/core/services/widget_pet_renderer.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const layout = PetAtlasLayout();
  test('Metadata describes the shared 64-pixel frame grid', () async {
    final metadata = jsonDecode(
      await File('assets/atlas_formato.json').readAsString(),
    ) as Map;
    expect(metadata['hoja']['celda_px'], [64, 64]);
    expect(metadata['hoja']['columnas'], layout.framesPerRow);
    expect(metadata['hoja']['filas'], layout.animationRows);
    expect((metadata['mascotas'] as List).length, PetSpecies.values.length * 2);
  });

  test(
    'Individual sheets share frame coordinates for every species and age',
    () {
      for (final species in PetSpecies.values) {
        for (final stage in PetGrowthStage.values) {
          expect(
            layout.frameRect(species: species, stage: stage, row: 0),
            const Rect.fromLTWH(0, 0, 64, 64),
          );
          expect(
            layout.frameRect(species: species, stage: stage, row: 9, frame: 7),
            const Rect.fromLTWH(448, 576, 64, 64),
          );
        }
      }
      for (final (row, frame) in [(-1, 0), (10, 0), (0, -1), (0, 8)]) {
        expect(
          () => layout.frameRect(
            species: PetSpecies.cat,
            stage: PetGrowthStage.baby,
            row: row,
            frame: frame,
          ),
          throwsRangeError,
        );
      }
    },
  );

  test(
    'Every supplied sheet has 80 complete frames and transparent margins',
    () async {
      for (final species in PetSpecies.values) {
        final style = PetSpeciesCatalog.forSpecies(species).first.key;
        for (final xp in [0, 200]) {
          final codec = await ui.instantiateImageCodec(
            await File(PetSpeciesCatalog.resolveAsset(style, xp: xp))
                .readAsBytes(),
          );
          final image = (await codec.getNextFrame()).image;
          codec.dispose();
          try {
            expect(
              Size(image.width.toDouble(), image.height.toDouble()),
              const Size(512, 640),
            );
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            for (var row = 0; row < 10; row++) {
              for (var frame = 0; frame < 8; frame++) {
                var visible = 0;
                for (var y = 0; y < 64; y++) {
                  for (var x = 0; x < 64; x++) {
                    final alpha = pixels.getUint8(
                      (((row * 64 + y) * image.width) + frame * 64 + x) * 4 + 3,
                    );
                    expect(alpha, anyOf(0, 255));
                    if (x == 0 || y == 0 || x == 63 || y == 63) {
                      expect(alpha, 0);
                    }
                    if (alpha > 0) visible++;
                  }
                }
                expect(
                  visible,
                  greaterThan(15),
                  reason: '${species.name}/$xp/$row/$frame',
                );
              }
            }
          } finally {
            image.dispose();
          }
        }
      }
    },
  );

  testWidgets(
    'Companion and Android widget render the same species, age and coat',
    (tester) async {
      for (final style in [
        for (final species in PetSpecies.values)
          PetSpeciesCatalog.forSpecies(species).first.key,
        'cream',
        'ink',
      ]) {
        for (final xp in [0, 200, 600]) {
          final settings = {'pet_style': style};
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TickerMode(
                  enabled: false,
                  child: KittyCompanionWidget(settings: settings, reward: xp),
                ),
              ),
            ),
          );
          final pack = await tester.runAsync(
            () => WidgetPetRenderer.render(settings, xp),
          );
          await tester.pump();
          final companion = find.descendant(
            of: find.byType(KittyCompanionWidget),
            matching: find.byType(CustomPaint),
          );
          final painter = tester.widget<CustomPaint>(companion).painter!;
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          const target = Rect.fromLTWH(0, 0, 256, 256);
          canvas.saveLayer(
            target,
            Paint()..colorFilter = PetSpeciesCatalog.get(style).colorFilter,
          );
          painter.paint(canvas, target.size);
          canvas.restore();
          final picture = recorder.endRecording();
          await tester.runAsync(() async {
            final expected = await picture.toImage(256, 256);
            final codec = await ui.instantiateImageCodec(
              base64Decode(pack!['idle']!),
            );
            final actual = (await codec.getNextFrame()).image;
            codec.dispose();
            try {
              final expectedData = (await expected.toByteData())!;
              final actualData = (await actual.toByteData())!;
              expect(
                actualData.buffer.asUint8List(),
                orderedEquals(expectedData.buffer.asUint8List()),
                reason: '$style/$xp',
              );
              // Reject blank renders even if both paths happen to produce them.
              expect(
                actualData.buffer.asUint8List().any((v) => v != 0),
                isTrue,
              );
            } finally {
              expected.dispose();
              actual.dispose();
            }
          });
          picture.dispose();
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
