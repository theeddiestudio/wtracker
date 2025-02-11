class FatEntry {
  final String date;
  final double neck;
  final double waist;
  final double? hip;
  final double? bodyFat;
  final double? fatMass;
  final double? leanMass;

  FatEntry({
    required this.date,
    required this.neck,
    required this.waist,
    this.hip,
    this.bodyFat,
    this.fatMass,
    this.leanMass,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'neck': double.parse(neck.toStringAsFixed(1)),
      'waist': double.parse(waist.toStringAsFixed(1)),
      'hip': hip != null ? double.parse(hip!.toStringAsFixed(1)) : null,
      'bodyFat':
          bodyFat != null ? double.parse(bodyFat!.toStringAsFixed(2)) : null,
      'fatMass':
          fatMass != null ? double.parse(fatMass!.toStringAsFixed(2)) : null,
      'leanMass':
          leanMass != null ? double.parse(leanMass!.toStringAsFixed(2)) : null,
    };
  }

  factory FatEntry.fromMap(Map<String, dynamic> map) {
    return FatEntry(
      date: map['date'],
      neck: map['neck'],
      waist: map['waist'],
      hip: map['hip'],
      bodyFat: map['bodyFat'],
      fatMass: map['fatMass'],
      leanMass: map['leanMass'],
    );
  }
}
