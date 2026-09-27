/// Format Duration to mm:ss or hh:mm:ss for retro displays.
class DurationFormatter {
  DurationFormatter._();

  static String format(Duration? duration) {
    if (duration == null || duration.inMilliseconds < 0) {
      return "00:00";
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hStr = hours.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    } else {
      return '$mStr:$sStr';
    }
  }
}
