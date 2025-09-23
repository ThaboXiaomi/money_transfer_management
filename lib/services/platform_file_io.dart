import 'dart:io';
import 'dart:typed_data';

bool pf_fileExists(String path) => File(path).existsSync();

Uint8List? pf_readFileBytes(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  return f.readAsBytesSync();
}

String pf_writeFileBytesSync(String dirPath, String filename, List<int> bytes) {
  final f = File('$dirPath/$filename');
  f.writeAsBytesSync(bytes);
  return f.path;
}

String pf_writeFileStringSync(String dirPath, String filename, String content) {
  final f = File('$dirPath/$filename');
  f.writeAsStringSync(content);
  return f.path;
}
