import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Outside the browser the file_picker plugin is used.
Future<Uint8List?> pickImageBytes() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  return file?.readAsBytes();
}

Future<void> downloadBytes(String name, Uint8List bytes, String mime) async {
  await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mime);
}
