class FatEntry {
  final String date;
  final String gender;
  final double height;
  final double weight;
  final double neck;
  final double waist;
  final double? hip;
  final double? bodyFat;

  FatEntry({
    required this.date,
    required this.gender,
    required this.height,
    required this.weight,
    required this.neck,
    required this.waist,
    this.hip,
    this.bodyFat,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'gender': gender,
      'height': height,
      'weight': weight,
      'neck': neck,
      'waist': waist,
      'hip': hip,
      'bodyFat': bodyFat != null
          ? double.parse(
              bodyFat!.toStringAsFixed(bodyFat! * 10 % 10 == 0 ? 1 : 2))
          : null,
    };
  }

  factory FatEntry.fromMap(Map<String, dynamic> map) {
    return FatEntry(
      date: map['date'],
      gender: map['gender'],
      height: map['height'],
      weight: map['weight'],
      neck: map['neck'],
      waist: map['waist'],
      hip: map['hip'],
      bodyFat: map['bodyFat'],
    );
  }
}
