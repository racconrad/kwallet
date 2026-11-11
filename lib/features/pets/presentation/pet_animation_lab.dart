import 'dart:async';

import 'package:flutter/material.dart';

import 'package:knotes/core/models/pet_species.dart';
import 'package:knotes/features/pets/presentation/pet_lab_grid.dart';

class PetAnimationLab extends StatefulWidget {
  const PetAnimationLab({super.key});

  @override
  State<PetAnimationLab> createState() => _PetAnimationLabState();
}

class _PetAnimationLabState extends State<PetAnimationLab>
    with WidgetsBindingObserver {
  static const _animations = [
    ('Idle', 240),
    ('Curious', 180),
    ('Happy', 180),
    ('Stretch', 180),
    ('Walk', 120),
    ('Run', 90),
    ('Sleep', 320),
    ('Groom', 180),
    ('Celebrate', 100),
    ('Relax', 160),
  ];
  final _frame = ValueNotifier<int>(0);
  Timer? _timer;
  int _row = 0;
  bool _playing = true;
  bool _foreground = true;
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!_playing ||
        !_foreground ||
        !TickerMode.valuesOf(context).enabled ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _timer = Timer.periodic(Duration(milliseconds: _animations[_row].$2), (_) {
      _frame.value = (_frame.value + 1) % 8;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pet animation lab'),
      actions: [
        IconButton(
          tooltip: _dark ? 'Light background' : 'Dark background',
          icon: Icon(
            _dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
          onPressed: () => setState(() => _dark = !_dark),
        ),
        IconButton(
          tooltip: _playing ? 'Pause' : 'Play',
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          onPressed: () {
            setState(() => _playing = !_playing);
            _schedule();
          },
        ),
        IconButton(
          tooltip: 'Next frame',
          icon: const Icon(Icons.skip_next),
          onPressed: () {
            setState(() => _playing = false);
            _schedule();
            _frame.value = (_frame.value + 1) % 8;
          },
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _row,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Animation'),
                  items: [
                    for (var i = 0; i < _animations.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          _animations[i].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (row) {
                    if (row == null) return;
                    setState(() => _row = row);
                    _frame.value = 0;
                    _schedule();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: _frame,
                      builder: (_, frame, child) =>
                          Text('Frame ${frame + 1} / 8'),
                    ),
                    Text(
                      '${PetSpeciesCatalog.styles.length * PetGrowthStage.values.length} pets · 8 × 8',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PetLabGrid(dark: _dark, row: _row, frame: _frame),
        ),
      ],
    ),
  );
}
