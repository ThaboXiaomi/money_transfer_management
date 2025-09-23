import 'dart:typed_data';

bool pf_fileExists(String path) => false;

Uint8List? pf_readFileBytes(String path) => null;

String pf_writeFileBytesSync(String dirPath, String filename, List<int> bytes) {
  // Not supported on web; return empty path
  return '';
}

String pf_writeFileStringSync(String dirPath, String filename, String content) {
  // Not supported on web; return empty path
  return '';
}
