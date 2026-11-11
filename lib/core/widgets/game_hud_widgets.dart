import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';

class ExpressiveButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color? color;
  final Color? textColor;
  final bool isOutlined;
  final EdgeInsetsGeometry padding;
  const ExpressiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.textColor,
    this.isOutlined = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  });

  @override
  Widget build(BuildContext context) => Material(
    color: isOutlined ? Colors.transparent : color ?? KnotesTheme.accent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: BorderSide(color: KnotesTheme.border, width: 1.5),
    ),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(padding: padding, child: child),
    ),
  );
}
