import 'dart:convert';
import 'dart:typed_data';

/// Minimal ZIP archive writer (files stored uncompressed), enough to hand
/// the creator every data file in one download.
class ZipWriter {
  final _entries = <(String, Uint8List)>[];

  void addText(String name, String text) => _entries.add((name, Uint8List.fromList(utf8.encode(text))));

  static final List<int> _crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  static int _crc32(Uint8List data) {
    var c = 0xFFFFFFFF;
    for (final b in data) {
      c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFF;
  }

  Uint8List build() {
    final out = BytesBuilder();
    final central = BytesBuilder();
    void u16(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
    void u32(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    for (final (name, data) in _entries) {
      final nameBytes = utf8.encode(name);
      final crc = _crc32(data);
      final offset = out.length;
      // Local file header.
      u32(out, 0x04034b50);
      u16(out, 20);
      u16(out, 0x0800); // UTF-8 names
      u16(out, 0); // stored
      u16(out, 0);
      u16(out, 0x21); // 1980-01-01
      u32(out, crc);
      u32(out, data.length);
      u32(out, data.length);
      u16(out, nameBytes.length);
      u16(out, 0);
      out.add(nameBytes);
      out.add(data);
      // Central directory entry.
      u32(central, 0x02014b50);
      u16(central, 20);
      u16(central, 20);
      u16(central, 0x0800);
      u16(central, 0);
      u16(central, 0);
      u16(central, 0x21);
      u32(central, crc);
      u32(central, data.length);
      u32(central, data.length);
      u16(central, nameBytes.length);
      u16(central, 0);
      u16(central, 0);
      u16(central, 0);
      u16(central, 0);
      u32(central, 0);
      u32(central, offset);
      central.add(nameBytes);
    }
    final centralBytes = central.toBytes();
    final start = out.length;
    out.add(centralBytes);
    u32(out, 0x06054b50);
    u16(out, 0);
    u16(out, 0);
    u16(out, _entries.length);
    u16(out, _entries.length);
    u32(out, centralBytes.length);
    u32(out, start);
    u16(out, 0);
    return out.toBytes();
  }
}
