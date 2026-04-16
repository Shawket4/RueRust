import 'package:flutter/material.dart';

/// Maps a category/item name to a themed icon + colour palette.
class CatStyle {
  final IconData icon;
  final Color bgTop, bgBottom, iconColor, accent;
  const CatStyle({
    required this.icon,
    required this.bgTop,
    required this.bgBottom,
    required this.iconColor,
    required this.accent,
  });

  static CatStyle of(String name) {
    final n = name.toLowerCase();
    if (n.contains('matcha'))
      return const CatStyle(
          icon: Icons.eco_rounded,
          bgTop: Color(0xFFE8F5E9),
          bgBottom: Color(0xFFC8E6C9),
          iconColor: Color(0xFF2E7D32),
          accent: Color(0xFF388E3C));
    if (n.contains('latte') ||
        n.contains('espresso') ||
        n.contains('americano') ||
        n.contains('cappuc') ||
        n.contains('flat') ||
        n.contains('cortado') ||
        n.contains('coffee') ||
        n.contains('v60') ||
        n.contains('blended') ||
        n.contains('cold brew'))
      return const CatStyle(
          icon: Icons.coffee_rounded,
          bgTop: Color(0xFFF5EEE6),
          bgBottom: Color(0xFFEDD9C0),
          iconColor: Color(0xFF5D4037),
          accent: Color(0xFF795548));
    if (n.contains('chocolate') || n.contains('mocha'))
      return const CatStyle(
          icon: Icons.coffee_rounded,
          bgTop: Color(0xFFF3E5E5),
          bgBottom: Color(0xFFE8CECE),
          iconColor: Color(0xFF6D4C41),
          accent: Color(0xFF8D3A3A));
    if (n.contains('croissant') ||
        n.contains('brownie') ||
        n.contains('cookie') ||
        n.contains('pastry') ||
        n.contains('pastries') ||
        n.contains('cake') ||
        n.contains('waffle'))
      return const CatStyle(
          icon: Icons.bakery_dining_rounded,
          bgTop: Color(0xFFFFF8E8),
          bgBottom: Color(0xFFFFF0C8),
          iconColor: Color(0xFFE65100),
          accent: Color(0xFFF57C00));
    if (n.contains('sandwich') ||
        n.contains('chicken') ||
        n.contains('turkey') ||
        n.contains('food'))
      return const CatStyle(
          icon: Icons.lunch_dining_rounded,
          bgTop: Color(0xFFFFF3E0),
          bgBottom: Color(0xFFFFE0B2),
          iconColor: Color(0xFFE64A19),
          accent: Color(0xFFEF6C00));
    if (n.contains('affogato') || n.contains('ice cream'))
      return const CatStyle(
          icon: Icons.icecream_rounded,
          bgTop: Color(0xFFF3E5F5),
          bgBottom: Color(0xFFE1BEE7),
          iconColor: Color(0xFF7B1FA2),
          accent: Color(0xFF9C27B0));
    if (n.contains('lemon') ||
        n.contains('lemonade') ||
        n.contains('refresher') ||
        n.contains('juice'))
      return const CatStyle(
          icon: Icons.local_drink_rounded,
          bgTop: Color(0xFFFFFDE7),
          bgBottom: Color(0xFFFFF9C4),
          iconColor: Color(0xFFF57F17),
          accent: Color(0xFFFBC02D));
    if (n.contains('tea') || n.contains('chai'))
      return const CatStyle(
          icon: Icons.emoji_food_beverage_rounded,
          bgTop: Color(0xFFE8F5E9),
          bgBottom: Color(0xFFC8E6C9),
          iconColor: Color(0xFF388E3C),
          accent: Color(0xFF43A047));
    if (n.contains('water') || n.contains('sparkling'))
      return const CatStyle(
          icon: Icons.water_drop_rounded,
          bgTop: Color(0xFFE3F2FD),
          bgBottom: Color(0xFFBBDEFB),
          iconColor: Color(0xFF1565C0),
          accent: Color(0xFF1976D2));
    if (n.contains('iced'))
      return const CatStyle(
          icon: Icons.ac_unit_rounded,
          bgTop: Color(0xFFE3F2FD),
          bgBottom: Color(0xFFBBDEFB),
          iconColor: Color(0xFF0277BD),
          accent: Color(0xFF0288D1));
    return const CatStyle(
        icon: Icons.local_cafe_rounded,
        bgTop: Color(0xFFF5EEE6),
        bgBottom: Color(0xFFEDD9C0),
        iconColor: Color(0xFF795548),
        accent: Color(0xFF8D6E63));
  }
}
