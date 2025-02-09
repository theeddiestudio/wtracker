class WeightEntry {
  int? id;
  String date; // Store as YYYY-MM-DD
  double? bwmrg;
  double? bwbg;
  double? bwag;
  double? bwslp;
  double? bwday;

  WeightEntry({
    this.id,
    required this.date,
    this.bwmrg,
    this.bwbg,
    this.bwag,
    this.bwslp,
    this.bwday,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'bwmrg': bwmrg,
      'bwbg': bwbg,
      'bwag': bwag,
      'bwslp': bwslp,
      'bwday': bwday != null
          ? double.parse(bwday!.toStringAsFixed(bwday! * 10 % 10 == 0 ? 1 : 2))
          : null, // Format bwday correctly
    };
  }

  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    return WeightEntry(
      id: map['id'],
      date: map['date'],
      bwmrg: map['bwmrg'],
      bwbg: map['bwbg'],
      bwag: map['bwag'],
      bwslp: map['bwslp'],
      bwday: map['bwday'],
    );
  }
}
