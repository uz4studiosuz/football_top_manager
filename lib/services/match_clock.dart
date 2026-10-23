/// A match minute lasts one real second at 1x. Wall time, never frame count,
/// drives the clock so speed changes and dropped frames cannot skip minutes.
class MatchClock {
  double minutes = 0;
  int speed = 1;
  bool paused = false;
  List<int> advance(Duration elapsed) {
    if (paused || minutes >= 90) return [];
    final before = minutes.floor();
    minutes = (minutes + elapsed.inMicroseconds / 1000000 * speed).clamp(0, 90);
    return [for (var m = before + 1; m <= minutes.floor(); m++) m];
  }
}
