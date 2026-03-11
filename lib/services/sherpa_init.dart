export 'sherpa_init_io.dart'
    if (dart.library.html) 'sherpa_init_web.dart'
    if (dart.library.js_interop) 'sherpa_init_web.dart';
