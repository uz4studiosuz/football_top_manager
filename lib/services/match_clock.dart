/// Reference-video pace: 26 match seconds in 19 wall seconds at 1x.
/// Wall time, never frame count,
/// drives the clock so speed changes and dropped frames cannot skip minutes.
class MatchClock {
  static const referenceRate = 26 / 19;
  static const rates = <String, double>{
    '1x': referenceRate / 60,
    '5x': 5 * referenceRate / 60,
    '10x': 10 * referenceRate / 60,
  };
  double minutes = 0;
  int speed = 1;
  bool paused = false;
  List<int> advance(Duration elapsed) {
    if (paused || minutes >= 90) return [];
    final before = minutes.floor();
    minutes =
        (minutes + elapsed.inMicroseconds / 60000000 * speed * referenceRate)
            .clamp(0, 90);
    return [for (var m = before + 1; m <= (minutes + 1e-9).floor(); m++) m];
  }
}
