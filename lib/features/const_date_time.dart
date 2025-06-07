class ConstDateTime implements DateTime {
  @override
  final int millisecondsSinceEpoch;

  const ConstDateTime(this.millisecondsSinceEpoch);

  @override
  DateTime add(Duration duration) => thisDT.add(duration);

  @override
  int compareTo(DateTime other) => thisDT.compareTo(other);

  DateTime get thisDT =>
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);

  @override
  int get day => thisDT.day;

  @override
  Duration difference(DateTime other) => thisDT.difference(other);

  @override
  int get hour => thisDT.hour;

  @override
  bool isAfter(DateTime other) => thisDT.isAfter(other);

  @override
  bool isAtSameMomentAs(DateTime other) => thisDT.isAtSameMomentAs(other);

  @override
  bool isBefore(DateTime other) => thisDT.isBefore(other);

  @override
  bool get isUtc => thisDT.isUtc;

  @override
  int get microsecond => thisDT.microsecond;

  @override
  int get microsecondsSinceEpoch => thisDT.microsecondsSinceEpoch;

  @override
  int get millisecond => thisDT.millisecond;

  @override
  int get minute => thisDT.minute;

  @override
  int get month => thisDT.month;

  @override
  int get second => thisDT.second;

  @override
  DateTime subtract(Duration duration) => thisDT.subtract(duration);

  @override
  String get timeZoneName => thisDT.timeZoneName;

  @override
  Duration get timeZoneOffset => thisDT.timeZoneOffset;

  @override
  String toIso8601String() => thisDT.toIso8601String();

  @override
  DateTime toLocal() => thisDT.toLocal();

  @override
  DateTime toUtc() => thisDT.toUtc();

  @override
  int get weekday => thisDT.weekday;

  @override
  int get year => thisDT.year;

  @override
  String toString() => thisDT.toIso8601String();
}
