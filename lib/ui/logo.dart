import 'package:flutter/material.dart';

import 'theme.dart';

class Logo extends StatelessWidget {
  const Logo({super.key, this.light = false, this.size = 36});
  final bool light;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: light ? AppColors.butter300 : AppColors.espresso,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(Icons.directions_car_filled_rounded, size: size * 0.58, color: light ? AppColors.espresso : AppColors.butter300),
      ),
      SizedBox(width: size * 0.25),
      Text(
        'AUTOX',
        style: TextStyle(
          fontSize: size * 0.55,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.4,
          color: light ? AppColors.butter50 : AppColors.espresso,
        ),
      ),
    ]);
  }
}
