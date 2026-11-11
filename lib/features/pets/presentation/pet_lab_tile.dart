import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:knotes/core/models/pet_species.dart';
import 'package:knotes/core/services/pet_atlas.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';
import 'package:knotes/core/widgets/pet_atlas_painter.dart';

class PetLabTile extends StatelessWidget {
  final PetStyleDef style;
  final PetGrowthStage stage;
  final int row;
  final int frame;
  final double spriteSize;

  const PetLabTile({
    super.key,
    required this.style,
    required this.stage,
    required this.row,
    required this.frame,
    required this.spriteSize,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final xp = switch (stage) {
      PetGrowthStage.baby => 0,
      PetGrowthStage.adult => 200,
      PetGrowthStage.master => 600,
    };
    final asset = PetSpeciesCatalog.resolveAsset(style.key, xp: xp);
    return Tooltip(
      message: '${style.key} / ${stage.name} / row $row / frame $frame',
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: spriteSize,
              child: FutureBuilder<ui.Image>(
                future: KittyCompanionWidget.loadAtlas(asset),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Icon(
                      Icons.broken_image_outlined,
                      semanticLabel: 'Asset failed to load',
                    );
                  }
                  final sprite = CustomPaint(
                    painter: PetAtlasPainter(
                      snapshot.data,
                      const PetAtlasLayout().frameRect(
                        species: style.species,
                        stage: stage,
                        row: row,
                        frame: frame,
                      ),
                    ),
                  );
                  return style.colorFilter == null
                      ? sprite
                      : ColorFiltered(
                          colorFilter: style.colorFilter!,
                          child: sprite,
                        );
                },
              ),
            ),
            Text(
              style.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text(
              '${style.species.name} · ${stage.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
