import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../domain/venue.dart';

/// Draws a floor plan scaled to the available width. [available] null means availability is unknown,
/// so every table can be selected; otherwise only the listed ids can.
class FloorPlanView extends StatelessWidget {
  const FloorPlanView({
    super.key,
    required this.plan,
    required this.available,
    required this.selectedId,
    required this.onSelect,
  });
  final FloorPlan plan;
  final Set<String>? available;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cw = plan.canvasWidth <= 0 ? 1000.0 : plan.canvasWidth;
      final ch = plan.canvasHeight <= 0 ? 800.0 : plan.canvasHeight;
      final width = constraints.maxWidth.isFinite ? constraints.maxWidth : cw;
      final scale = width / cw;
      return Container(
        width: width,
        height: ch * scale,
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(children: [for (final t in plan.tables) _tile(t, scale)]),
      );
    });
  }

  Widget _tile(VenueTable t, double scale) {
    final free = available == null || available!.contains(t.id);
    final selected = t.id == selectedId;
    final edge = free ? AppColors.gold : AppColors.border;
    final radius = t.shape == 'rect'
        ? BorderRadius.circular((10 * scale.clamp(0.4, 1.0)).toDouble())
        : BorderRadius.circular(math.max(t.w, t.h) * scale);
    final textColor = selected ? Colors.black : (free ? AppColors.textPrimary : AppColors.textSecondary);
    return Positioned(
      left: t.x * scale,
      top: t.y * scale,
      width: t.w * scale,
      height: t.h * scale,
      child: Transform.rotate(
        angle: t.rotation * math.pi / 180,
        child: GestureDetector(
          onTap: free ? () => onSelect(t.id) : null,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.gold : (free ? AppColors.gold.withAlpha(30) : const Color(0x0AFFFFFF)),
              borderRadius: radius,
              border: Border.all(color: edge, width: selected ? 2 : 1),
            ),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(t.number, style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
                  Text('${t.capacity}', style: TextStyle(fontSize: 11, color: textColor)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
