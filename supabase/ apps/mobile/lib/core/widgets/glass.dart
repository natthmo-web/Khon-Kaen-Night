import 'package:flutter/material.dart';

import '../theme/tokens.dart';

const _glassFill = Color(0x14FFFFFF);

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class GlassButton extends StatelessWidget {
  const GlassButton({super.key, required this.label, required this.onPressed, this.loading = false, this.secondary = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading, secondary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
        color: secondary ? _glassFill : AppColors.gold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: secondary ? const BorderSide(color: AppColors.border) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: Center(
              child: loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      label,
                      style: TextStyle(fontWeight: FontWeight.w600, color: secondary ? AppColors.textPrimary : Colors.black),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.label, this.selected = false, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.gold : _glassFill,
      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.gold : AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(label, style: TextStyle(fontSize: 13, color: selected ? Colors.black : AppColors.textPrimary)),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: const Color(0x66000000),
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20)),
        ),
      ),
    );
  }
}

class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.obscureText = false,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      obscureText: obscureText,
      decoration: InputDecoration(labelText: label),
    );
  }
}
