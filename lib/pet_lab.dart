import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/pets/presentation/pet_animation_lab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: 'knotes · Pet animation lab',
      debugShowCheckedModeBanner: false,
      theme: KnotesTheme.expressiveTheme,
      home: const PetAnimationLab(),
    ),
  );
}
