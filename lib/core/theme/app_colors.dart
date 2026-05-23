import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary - warm amber-orange adventure palette
  static const Color primary = Color(0xFFFF8C00);
  static const Color primaryLight = Color(0xFFFFAD42);
  static const Color primaryDark = Color(0xFFCC7000);

  // Background
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2A2A2A);
  static const Color surfaceHighlight = Color(0xFF333333);

  // Text
  static const Color textPrimary = Color(0xFFE8E8E8);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textHint = Color(0xFF777777);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);

  // Expense categories
  static const Color fuel = Color(0xFFFF7043);
  static const Color food = Color(0xFFFFCA28);
  static const Color lodging = Color(0xFF42A5F5);
  static const Color camping = Color(0xFF66BB6A);
  static const Color gear = Color(0xFFAB47BC);
  static const Color maintenance = Color(0xFF78909C);
  static const Color tolls = Color(0xFF8D6E63);
  static const Color entertainment = Color(0xFFEC407A);
  static const Color other = Color(0xFF9E9E9E);

  // Segment colors for multi-segment route rendering
  static const List<Color> segmentColors = [
    Color(0xFFFF8C00), // orange (primary)
    Color(0xFF42A5F5), // blue
    Color(0xFF66BB6A), // green
    Color(0xFFAB47BC), // purple
    Color(0xFFEF5350), // red
    Color(0xFFFFCA28), // yellow
    Color(0xFF26C6DA), // cyan
    Color(0xFFEC407A), // pink
  ];

  // Stop type colors
  static const Color stopStart = Color(0xFF4CAF50);
  static const Color stopFuel = Color(0xFFFF7043);
  static const Color stopFood = Color(0xFFFFCA28);
  static const Color stopScenic = Color(0xFF42A5F5);
  static const Color stopCampsite = Color(0xFF66BB6A);
  static const Color stopLodging = Color(0xFF7E57C2);
  static const Color stopRest = Color(0xFF78909C);
  static const Color stopDestination = Color(0xFFFF8C00);
  static const Color stopWaypoint = Color(0xFF90A4AE);
  static const Color stopShapePoint = Color(0xFF546E7A);

  static Color expenseCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'fuel':
        return fuel;
      case 'food':
        return food;
      case 'lodging':
        return lodging;
      case 'camping':
        return camping;
      case 'gear':
        return gear;
      case 'maintenance':
        return maintenance;
      case 'tolls':
        return tolls;
      case 'entertainment':
        return entertainment;
      default:
        return other;
    }
  }

  static Color stopTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'start':
        return stopStart;
      case 'fuel':
        return stopFuel;
      case 'food':
        return stopFood;
      case 'scenic':
        return stopScenic;
      case 'campsite':
        return stopCampsite;
      case 'lodging':
        return stopLodging;
      case 'rest':
        return stopRest;
      case 'destination':
        return stopDestination;
      case 'waypoint':
        return stopWaypoint;
      case 'shapepoint':
        return stopShapePoint;
      default:
        return other;
    }
  }
}
