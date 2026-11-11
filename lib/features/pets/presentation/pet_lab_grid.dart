import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:knotes/core/models/pet_species.dart';
import 'package:knotes/core/services/pet_atlas.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/pets/presentation/pet_lab_tile.dart';

class PetLabGrid extends StatefulWidget {
  final bool dark;
  final int row;
  final ValueNotifier<int> frame;

  const PetLabGrid({
    super.key,
    required this.dark,
    required this.row,
    required this.frame,
  });

  @override
  State<PetLabGrid> createState() => _PetLabGridState();
}

class _PetLabGridState extends State<PetLabGrid> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cellSize = const PetAtlasLayout().cellSize.width;
      final labelHeight = MediaQuery.textScalerOf(context).scale(32);
      final height = math.max(
        constraints.maxHeight,
        8 * (cellSize + labelHeight),
      );
      final spriteSize = math.max(
        cellSize,
        math.min(
          cellSize * 2,
          ((height / 8 - labelHeight) / cellSize).floor() * cellSize,
        ),
      );
      final width = math.max(
        constraints.maxWidth,
        math.max(896.0, 8 * spriteSize),
      );
      final pets = [
        for (final style in PetSpeciesCatalog.styles.values)
          for (final stage in PetGrowthStage.values) (style, stage),
      ];
      return Theme(
        data: ThemeData(
          colorSchemeSeed: KnotesTheme.accent,
          brightness: widget.dark ? Brightness.dark : Brightness.light,
          useMaterial3: true,
        ),
        child: Builder(
          builder: (context) => Material(
            color: Theme.of(context).colorScheme.surface,
            child: Scrollbar(
              controller: _vertical,
              child: SingleChildScrollView(
                controller: _vertical,
                child: Scrollbar(
                  controller: _horizontal,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: ValueListenableBuilder<int>(
                        valueListenable: widget.frame,
                        builder: (_, frame, child) => GridView.count(
                          crossAxisCount: 8,
                          mainAxisExtent: height / 8,
                          physics: const NeverScrollableScrollPhysics(),
                          primary: false,
                          padding: EdgeInsets.zero,
                          children: [
                            for (var i = 0; i < 64; i++)
                              if (i < pets.length)
                                PetLabTile(
                                  key: ValueKey(
                                    '${pets[i].$1.key}/${pets[i].$2.name}',
                                  ),
                                  style: pets[i].$1,
                                  stage: pets[i].$2,
                                  row: widget.row,
                                  frame: frame,
                                  spriteSize: spriteSize,
                                )
                              else
                                const SizedBox.shrink(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
