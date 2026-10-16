import 'package:flutter/material.dart';

/// Kaydedilebilir spor / aktivite türü. [met] = metabolik eşdeğer (kcal/kg/saat).
class Sport {
  final String id;
  final String name;
  final double met;
  final IconData icon;

  const Sport(this.id, this.name, this.met, this.icon);

  /// Süre ve kiloya göre yakılan kalori: MET × kg × saat.
  int caloriesFor({required int minutes, required double weightKg}) {
    if (minutes <= 0) return 0;
    return (met * weightKg * minutes / 60).round();
  }
}

const List<Sport> sports = [
  Sport('walk', 'Yürüyüş', 3.8, Icons.directions_walk),
  Sport('run', 'Koşu', 9.8, Icons.directions_run),
  Sport('bike', 'Bisiklet', 7.5, Icons.directions_bike),
  Sport('swim', 'Yüzme', 8.0, Icons.pool),
  Sport('gym', 'Ağırlık Antrenmanı', 5.0, Icons.fitness_center),
  Sport('hiit', 'HIIT', 8.0, Icons.bolt),
  Sport('football', 'Futbol', 7.0, Icons.sports_soccer),
  Sport('basketball', 'Basketbol', 6.5, Icons.sports_basketball),
  Sport('tennis', 'Tenis', 7.3, Icons.sports_tennis),
  Sport('boxing', 'Boks', 9.0, Icons.sports_mma),
  Sport('rope', 'İp Atlama', 11.0, Icons.sports_gymnastics),
  Sport('yoga', 'Yoga', 2.5, Icons.self_improvement),
  Sport('pilates', 'Pilates', 3.0, Icons.accessibility_new),
  Sport('dance', 'Dans', 5.0, Icons.music_note),
  Sport('climb', 'Tırmanış', 8.0, Icons.terrain),
  Sport('other', 'Diğer', 4.0, Icons.sports),
];

Sport sportById(String id) =>
    sports.firstWhere((s) => s.id == id, orElse: () => sports.last);
