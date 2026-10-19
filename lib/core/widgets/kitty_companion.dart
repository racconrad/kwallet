import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pet_species.dart';

enum PetActivity { idle, walk, run, sleep, curious, celebrate, relax, grabbed }

Map<String, String> get petStyles => PetSpeciesCatalog.namesMap;

class KittyCompanionWidget extends StatefulWidget {
  final Map<String, String> settings;
  final PetActivity activity;
  final String name;
  final double size;
  final VoidCallback? onPet;
  final ValueChanged<PetActivity>? onActivityChanged;
  final String? imagePath;
  final int reward;
  const KittyCompanionWidget({
    super.key,
    this.settings = const {},
    this.activity = PetActivity.idle,
    this.name = 'Mishi',
    this.size = 96,
    this.onPet,
    this.onActivityChanged,
    this.imagePath,
    this.reward = 0,
  });

  static final Map<String, Future<ui.Image>> _atlasCache = {};

  static Future<ui.Image> loadAtlas(String path) {
    return _atlasCache.putIfAbsent(path, () async {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    });
  }

  @override
  State<KittyCompanionWidget> createState() => _KittyCompanionWidgetState();
}

class _KittyCompanionWidgetState extends State<KittyCompanionWidget>
    with WidgetsBindingObserver {
  static String? _imageData;
  static Uint8List? _imageBytes;
  ui.Image? _atlas;
  Uint8List? _customImage;
  Timer? _timer;
  PetActivity? _reaction;
  PetActivity? _reportedActivity;
  int _frame = 0;
  int _pets = 0;
  bool _foreground = true;
  bool _enabled = false;
  String get _name => widget.settings['pet_name'] ?? widget.name;
  String? get _legacyPath => widget.settings.containsKey('pet_style')
      ? null
      : widget.imagePath ?? widget.settings['pet_image'];
  PetActivity get _activity => _reaction ?? widget.activity;
  (int, int, int) get _sequence => switch (_activity) {
    PetActivity.idle => (0, 4, 320),
    PetActivity.walk => (4, 8, 120),
    PetActivity.run => (5, 8, 90),
    PetActivity.sleep => (6, 4, 420),
    PetActivity.curious => (7, 6, 140),
    PetActivity.celebrate => (8, 7, 100),
    PetActivity.relax => (9, 8, 160),
    PetActivity.grabbed => (8, 4, 180),
  };

  String get _currentAsset => PetSpeciesCatalog.resolveAsset(
    widget.settings['pet_style'],
    xp: widget.reward,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readImage();
    _loadCurrentAtlas();
  }

  void _loadCurrentAtlas() {
    final asset = _currentAsset;
    KittyCompanionWidget.loadAtlas(asset).then((image) {
      if (mounted) setState(() => _atlas = image);
    }, onError: (_, _) {});
  }

  void _readImage() {
    _customImage = null;
    if (widget.settings['pet_style'] != 'custom') return;
    try {
      final data = widget.settings['pet_image_data'];
      if (data != null && data.length <= 5600000) {
        if (_imageData != data) {
          _imageBytes = base64Decode(data);
          _imageData = data;
        }
        _customImage = _imageBytes;
      }
    } on FormatException {
      _customImage = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(KittyCompanionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedPet =
        widget.settings['pet_image_data'] !=
            oldWidget.settings['pet_image_data'] ||
        widget.settings['pet_style'] != oldWidget.settings['pet_style'];
    final changedStage =
        PetGrowthStage.fromXp(widget.reward) !=
        PetGrowthStage.fromXp(oldWidget.reward);
    if (changedPet || changedStage) {
      if (changedPet) _readImage();
      _loadCurrentAtlas();
    }
    if (widget.activity != oldWidget.activity) _frame = 0;
    if (widget.reward > oldWidget.reward) {
      _react(PetActivity.celebrate);
    } else if (changedPet) {
      _react(PetActivity.curious);
    } else {
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    _enabled =
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (!_enabled) {
      _reaction = null;
      _frame = 0;
      return;
    }
    if ((_customImage != null || _legacyPath?.isNotEmpty == true) &&
        _reaction == null &&
        (widget.activity == PetActivity.idle ||
            widget.activity == PetActivity.sleep ||
            widget.activity == PetActivity.relax)) {
      _enabled = false;
      return;
    }
    final (_, frames, milliseconds) = _sequence;
    _timer = Timer.periodic(Duration(milliseconds: milliseconds), (_) {
      if (!mounted) return;
      setState(() {
        _frame++;
        if (_frame >= frames) {
          _frame = 0;
          if (_reaction != null) {
            _reaction = null;
            _schedule();
          }
        }
      });
    });
  }

  void _react(PetActivity reaction) {
    setState(() {
      _frame = 0;
      _reaction = reaction;
    });
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reportedActivity != _activity) {
      _reportedActivity = _activity;
      final activity = _activity;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onActivityChanged?.call(activity);
      });
    }
    final image = _customImage != null
        ? Image.memory(
            _customImage!,
            cacheWidth: math.min(
              512,
              (widget.size * MediaQuery.devicePixelRatioOf(context)).ceil(),
            ),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, _, _) => _sprite(),
          )
        : _legacyPath?.isNotEmpty == true
        ? Image.file(
            File(_legacyPath!),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, _, _) => _sprite(),
          )
        : _sprite();
    final progress =
        _enabled && (_customImage != null || _legacyPath?.isNotEmpty == true)
        ? math.sin(math.pi * _frame / _sequence.$2)
        : 0.0;
    return Semantics(
      label: _name,
      button: true,
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Tooltip(
          message: 'Acariciar a $_name',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.selectionClick();
              _react(
                [
                  PetActivity.curious,
                  PetActivity.relax,
                  PetActivity.celebrate,
                ][_pets++ % 3],
              );
              widget.onPet?.call();
            },
            child: RepaintBoundary(
              child: SizedBox.square(
                dimension: widget.size,
                child: Transform.translate(
                  offset: Offset(0, -6 * progress),
                  child: Transform.rotate(angle: .08 * progress, child: image),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sprite() {
    final sprite = CustomPaint(
      painter: _AtlasPainter(
        _atlas,
        _sequence.$1,
        _enabled ? _frame % _sequence.$2 : 0,
      ),
    );
    final style = widget.settings['pet_style'];
    final filter = PetSpeciesCatalog.get(style).colorFilter;
    if (filter != null) {
      return ColorFiltered(colorFilter: filter, child: sprite);
    }
    return sprite;
  }
}

class _AtlasPainter extends CustomPainter {
  final ui.Image? atlas;
  final int row;
  final int frame;
  _AtlasPainter(this.atlas, this.row, this.frame);
  @override
  void paint(Canvas canvas, Size size) {
    if (atlas == null) return;
    // Full 32x32 frame cell ensures no tails, ears, or snouts are clipped
    final source = Rect.fromLTWH(frame * 32.0, row * 32.0, 32.0, 32.0);
    final target = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(
      atlas!,
      source,
      target,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_AtlasPainter oldDelegate) =>
      atlas != oldDelegate.atlas ||
      row != oldDelegate.row ||
      frame != oldDelegate.frame;
}
