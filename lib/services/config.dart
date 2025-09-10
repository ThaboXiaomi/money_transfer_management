// Conditional platform-safe export: use the IO implementation on native
// platforms and a web-friendly implementation when compiling to web.
export 'config_io.dart' if (dart.library.html) 'config_web.dart';
