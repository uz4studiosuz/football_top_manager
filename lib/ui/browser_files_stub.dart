import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Outside the browser the file_picker plugin is used.
Future<Uint8List?> pickImageBytes() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  return file?.readAsBytes();
}

/// [accept] like '.json': the extensions after the dots are allowed.
Future<Uint8List?> pickFileBytes(String accept) async {
  final ext = [for (final a in accept.split(',')) a.trim().replaceFirst('.', '')]..removeWhere((e) => e.isEmpty || e.contains('/'));
  final file = await FilePicker.pickFile(type: ext.isEmpty ? FileType.any : FileType.custom, allowedExtensions: ext.isEmpty ? null : ext);
  return file?.readAsBytes();
}

Future<void> downloadBytes(String name, Uint8List bytes, String mime) async {
  await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mime);
}
