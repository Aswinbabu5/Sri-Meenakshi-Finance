export 'safe_image_provider_stub.dart'
    if (dart.library.html) 'safe_image_provider_web.dart'
    if (dart.library.io) 'safe_image_provider_io.dart';
