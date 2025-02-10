class WeekEntry {
  int? id;
  String df; // Date From (YYYY-MM-DD, past Sunday)
  String dt; // Date To (YYYY-MM-DD, future Saturday)
  double bwwk; // Weekly average weight

  WeekEntry({
    this.id,
    required this.df,
    required this.dt,
    required this.bwwk,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'df': df,
      'dt': dt,
      'bwwk': bwwk != null
          ? double.parse(bwwk!.toStringAsFixed(bwwk! * 10 % 10 == 0 ? 1 : 2))
          : null,
    };
  }

  factory WeekEntry.fromMap(Map<String, dynamic> map) {
    return WeekEntry(
      id: map['id'],
      df: map['df'],
      dt: map['dt'],
      bwwk: map['bwwk'],
    );
  }
}
