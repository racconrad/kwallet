import 'dart:math' as math;

import 'package:flutter/material.dart';

enum PetSpecies {
  cat('Gato'),
  rat('Rata'),
  raccoon('Mapache'),
  opossum('Zarigüeya'),
  rock('Roca'),
  plant('Planta'),
  golem('Gólem');

  final String label;
  const PetSpecies(this.label);
}

enum PetGrowthStage {
  baby('Bebé', 0.85),
  adult('Adulto', 1.0),
  master('Maestro', 1.15);

  final String title;
  final double scale;
  const PetGrowthStage(this.title, this.scale);

  static PetGrowthStage fromXp(int xp) {
    if (xp < 200) return PetGrowthStage.baby;
    if (xp < 600) return PetGrowthStage.adult;
    return PetGrowthStage.master;
  }
}

class PetStyleDef {
  final String key;
  final String name;
  final PetSpecies species;
  final String asset;
  final ColorFilter? colorFilter;

  const PetStyleDef({
    required this.key,
    required this.name,
    required this.species,
    required this.asset,
    this.colorFilter,
  });
}

class PetSpeciesCatalog {
  static const Map<String, PetStyleDef> styles = {
    // Cats
    'classic': PetStyleDef(
      key: 'classic',
      name: 'Mishi',
      species: PetSpecies.cat,
      asset: 'assets/pets/cat.png',
    ),
    'cream': PetStyleDef(
      key: 'cream',
      name: 'Canela',
      species: PetSpecies.cat,
      asset: 'assets/pets/cat.png',
      colorFilter: ColorFilter.matrix([
        1.1,
        0,
        0,
        0,
        14,
        0,
        .9,
        0,
        0,
        9,
        0,
        0,
        .6,
        0,
        3,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    'ink': PetStyleDef(
      key: 'ink',
      name: 'Sombra',
      species: PetSpecies.cat,
      asset: 'assets/pets/cat.png',
      colorFilter: ColorFilter.matrix([
        .55,
        0,
        0,
        0,
        6,
        0,
        .58,
        0,
        0,
        8,
        0,
        0,
        .5,
        0,
        6,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    'ginger': PetStyleDef(
      key: 'ginger',
      name: 'Naranjito',
      species: PetSpecies.cat,
      asset: 'assets/pets/cat.png',
      colorFilter: ColorFilter.matrix([
        1.3,
        0,
        0,
        0,
        25,
        0,
        .85,
        0,
        0,
        -5,
        0,
        0,
        .45,
        0,
        -18,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    'siamese': PetStyleDef(
      key: 'siamese',
      name: 'Milo',
      species: PetSpecies.cat,
      asset: 'assets/pets/cat.png',
      colorFilter: ColorFilter.matrix([
        1.05,
        0,
        0,
        0,
        15,
        0,
        1.0,
        0,
        0,
        8,
        0,
        0,
        .85,
        0,
        2,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    'calico': PetStyleDef(
      key: 'calico',
      name: 'Manchas',
      species: PetSpecies.cat,
      asset: 'assets/pets/cat.png',
      colorFilter: ColorFilter.matrix([
        1.2,
        0,
        0,
        0,
        18,
        0,
        .95,
        0,
        0,
        2,
        0,
        0,
        .6,
        0,
        -8,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    'silver': PetStyleDef(
      key: 'silver',
      name: 'Plata',
      species: PetSpecies.cat,
      asset: 'assets/pets/cat.png',
      colorFilter: ColorFilter.matrix([
        .7,
        0,
        0,
        0,
        22,
        0,
        .75,
        0,
        0,
        28,
        0,
        0,
        .85,
        0,
        42,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    'snow': PetStyleDef(
      key: 'snow',
      name: 'Copito',
      species: PetSpecies.cat,
      asset: 'assets/pets/cat.png',
      colorFilter: ColorFilter.matrix([
        1.25,
        0,
        0,
        0,
        38,
        0,
        1.25,
        0,
        0,
        38,
        0,
        0,
        1.35,
        0,
        46,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),

    // Rats - various colors
    'rat_snow': PetStyleDef(
      key: 'rat_snow',
      name: 'Quesito',
      species: PetSpecies.rat,
      asset: 'assets/pets/rat.png',
      colorFilter: ColorFilter.matrix([
        1.25,
        0,
        0,
        0,
        35,
        0,
        1.25,
        0,
        0,
        35,
        0,
        0,
        1.25,
        0,
        35,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    'rat_hooded': PetStyleDef(
      key: 'rat_hooded',
      name: 'Remi',
      species: PetSpecies.rat,
      asset: 'assets/pets/rat.png',
      colorFilter: ColorFilter.matrix([
        1.1,
        0,
        0,
        0,
        12,
        0,
        .95,
        0,
        0,
        4,
        0,
        0,
        .8,
        0,
        -6,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    'rat_slate': PetStyleDef(
      key: 'rat_slate',
      name: 'Bigotes',
      species: PetSpecies.rat,
      asset: 'assets/pets/rat.png',
      colorFilter: ColorFilter.matrix([
        .8,
        0,
        0,
        0,
        15,
        0,
        .85,
        0,
        0,
        20,
        0,
        0,
        .95,
        0,
        30,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    'rat_golden': PetStyleDef(
      key: 'rat_golden',
      name: 'Pecano',
      species: PetSpecies.rat,
      asset: 'assets/pets/rat.png',
      colorFilter: ColorFilter.matrix([
        1.25,
        0,
        0,
        0,
        24,
        0,
        .9,
        0,
        0,
        2,
        0,
        0,
        .5,
        0,
        -15,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    'rat_ink': PetStyleDef(
      key: 'rat_ink',
      name: 'Pimienta',
      species: PetSpecies.rat,
      asset: 'assets/pets/rat.png',
      colorFilter: ColorFilter.matrix([
        .55,
        0,
        0,
        0,
        8,
        0,
        .55,
        0,
        0,
        8,
        0,
        0,
        .58,
        0,
        10,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),

    'opossum_classic': PetStyleDef(
      key: 'opossum_classic',
      name: 'Pepita',
      species: PetSpecies.opossum,
      asset: 'assets/pets/opossum.png',
    ),
    'rock_classic': PetStyleDef(
      key: 'rock_classic',
      name: 'Roco',
      species: PetSpecies.rock,
      asset: 'assets/pets/rock.png',
    ),
    'plant_classic': PetStyleDef(
      key: 'plant_classic',
      name: 'Brotito',
      species: PetSpecies.plant,
      asset: 'assets/pets/plant.png',
    ),

    'golem_classic': PetStyleDef(
      key: 'golem_classic',
      name: 'Terrón',
      species: PetSpecies.golem,
      asset: 'assets/pets/golem.png',
    ),

    // Raccoons
    'raccoon_classic': PetStyleDef(
      key: 'raccoon_classic',
      name: 'Bandido',
      species: PetSpecies.raccoon,
      asset: 'assets/pets/raccoon.png',
    ),
    'raccoon_cinnamon': PetStyleDef(
      key: 'raccoon_cinnamon',
      name: 'Canelo',
      species: PetSpecies.raccoon,
      asset: 'assets/pets/raccoon.png',
      colorFilter: ColorFilter.matrix([
        1.2,
        0,
        0,
        0,
        20,
        0,
        .85,
        0,
        0,
        0,
        0,
        0,
        .55,
        0,
        -12,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    'raccoon_frost': PetStyleDef(
      key: 'raccoon_frost',
      name: 'Neblina',
      species: PetSpecies.raccoon,
      asset: 'assets/pets/raccoon.png',
      colorFilter: ColorFilter.matrix([
        .85,
        0,
        0,
        0,
        28,
        0,
        .9,
        0,
        0,
        32,
        0,
        0,
        1.05,
        0,
        42,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
  };

  static Map<String, String> get namesMap => {
    for (final e in styles.entries) e.key: e.value.name,
  };

  static PetStyleDef get(String? key) => styles[key] ?? styles['classic']!;

  static List<PetStyleDef> forSpecies(PetSpecies? species) {
    if (species == null) return styles.values.toList();
    return styles.values.where((s) => s.species == species).toList();
  }

  static PetStyleDef pickRandom({PetSpecies? species}) {
    final list = forSpecies(species);
    final random = math.Random();
    return list[random.nextInt(list.length)];
  }

  static String resolveAsset(String? styleKey, {int xp = 0}) {
    final asset = get(styleKey).asset;
    return PetGrowthStage.fromXp(xp) == PetGrowthStage.baby
        ? asset.replaceFirst('.png', '_baby.png')
        : asset;
  }
}
