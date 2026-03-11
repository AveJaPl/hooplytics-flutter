export 'background_asr_service_io.dart'
    if (dart.library.html) 'background_asr_service_web.dart'
    if (dart.library.js_interop) 'background_asr_service_web.dart';
