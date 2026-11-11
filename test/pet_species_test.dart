import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knotes/core/models/pet_species.dart';
import 'package:knotes/core/widgets/pet_selection_panel.dart';

void main() {
  group('PetSpecies and Catalog Tests', () {
    test('Catalog contains all species and valid styles', () {
      final cats = PetSpeciesCatalog.forSpecies(PetSpecies.cat);
      final rats = PetSpeciesCatalog.forSpecies(PetSpecies.rat);
      final raccoons = PetSpeciesCatalog.forSpecies(PetSpecies.raccoon);

      expect(cats.length, greaterThanOrEqualTo(8));
      expect(rats.length, equals(5));
      expect(raccoons.length, equals(3));
      for (final species in PetSpecies.values) {
        expect(PetSpeciesCatalog.forSpecies(species), isNotEmpty);
      }

      // Test rat varieties
      final ratKeys = rats.map((r) => r.key).toSet();
      expect(
        ratKeys,
        containsAll([
          'rat_snow',
          'rat_hooded',
          'rat_slate',
          'rat_golden',
          'rat_ink',
        ]),
      );

      // Test raccoon varieties
      final raccoonKeys = raccoons.map((r) => r.key).toSet();
      expect(
        raccoonKeys,
        containsAll(['raccoon_classic', 'raccoon_cinnamon', 'raccoon_frost']),
      );
    });

    test('Growth stage computes scale and title correctly based on XP', () {
      expect(PetGrowthStage.fromXp(0), equals(PetGrowthStage.baby));
      expect(PetGrowthStage.fromXp(199), equals(PetGrowthStage.baby));
      expect(PetGrowthStage.fromXp(200), equals(PetGrowthStage.adult));
      expect(PetGrowthStage.fromXp(599), equals(PetGrowthStage.adult));
      expect(PetGrowthStage.fromXp(600), equals(PetGrowthStage.master));
      expect(PetGrowthStage.fromXp(1200), equals(PetGrowthStage.master));

      expect(PetGrowthStage.baby.scale, equals(0.85));
      expect(PetGrowthStage.adult.scale, equals(1.0));
      expect(PetGrowthStage.master.scale, equals(1.15));
    });

    test('Every style resolves its species and growth sheet', () {
      for (final style in PetSpeciesCatalog.styles.values) {
        for (final xp in [0, 199, 200, 599, 600]) {
          expect(
            PetSpeciesCatalog.resolveAsset(style.key, xp: xp),
            'assets/pets/${style.species.name}${xp < 200 ? '_baby' : ''}.png',
          );
        }
      }
      expect(PetSpeciesCatalog.get('unknown').key, 'classic');
      expect(PetSpeciesCatalog.resolveAsset(null), 'assets/pets/cat_baby.png');
    });

    test('Random pet selection returns valid style', () {
      final randomAny = PetSpeciesCatalog.pickRandom();
      expect(PetSpeciesCatalog.styles.containsKey(randomAny.key), isTrue);

      final randomRat = PetSpeciesCatalog.pickRandom(species: PetSpecies.rat);
      expect(randomRat.species, equals(PetSpecies.rat));

      final randomRaccoon = PetSpeciesCatalog.pickRandom(
        species: PetSpecies.raccoon,
      );
      expect(randomRaccoon.species, equals(PetSpecies.raccoon));
      for (final species in PetSpecies.values) {
        expect(PetSpeciesCatalog.pickRandom(species: species).species, species);
      }
    });
  });

  group('PetSelectionPanel Widget Tests', () {
    testWidgets('Renders species filter chips and triggers random selection', (
      tester,
    ) async {
      String selected = 'classic';
      String? suggestedName;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PetSelectionPanel(
              selectedStyle: selected,
              onSelectStyle: (style) => selected = style,
              onNameSuggested: (name) => suggestedName = name,
            ),
          ),
        ),
      );

      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Gato'), findsOneWidget);
      expect(find.text('Rata'), findsOneWidget);
      expect(find.text('Mapache'), findsOneWidget);
      expect(find.text('Zarigüeya'), findsOneWidget);
      expect(find.text('Roca'), findsOneWidget);
      expect(find.text('Planta'), findsOneWidget);
      expect(find.text('Al azar'), findsOneWidget);

      // Tap Rat filter
      await tester.tap(find.text('Rata'));
      await tester.pump();

      expect(find.text('Remi'), findsOneWidget);
      expect(find.text('Quesito'), findsOneWidget);

      // Tap random button
      await tester.ensureVisible(find.text('Al azar'));
      await tester.tap(find.text('Al azar'));
      await tester.pump();

      expect(suggestedName, isNotNull);

      // Scrollable species filters work for the new companions too.
      for (final entry in {
        'Zarigüeya': 'Pepita',
        'Roca': 'Roco',
        'Planta': 'Brotito',
      }.entries) {
        await tester.ensureVisible(find.text(entry.key));
        await tester.tap(find.text(entry.key));
        await tester.pump();
        await tester.tap(find.text(entry.value));
        await tester.pump();
        expect(suggestedName, entry.value);
        expect(PetSpeciesCatalog.get(selected).species.label, entry.key);
      }
    });
  });
}
