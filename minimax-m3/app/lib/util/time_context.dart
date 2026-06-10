/// Time-of-day / weekday context used by ranking and home-feed defaults.
class TimeContext {
  final bool isMorning; // 5am–11am
  final bool isEvening; // 5pm–9pm
  final bool isWeekend; // Sat or Sun

  const TimeContext({
    required this.isMorning,
    required this.isEvening,
    required this.isWeekend,
  });

  factory TimeContext.from(DateTime when) {
    final h = when.hour;
    return TimeContext(
      isMorning: h >= 5 && h < 11,
      isEvening: h >= 17 && h < 21,
      isWeekend: when.weekday == DateTime.saturday ||
          when.weekday == DateTime.sunday,
    );
  }
}
