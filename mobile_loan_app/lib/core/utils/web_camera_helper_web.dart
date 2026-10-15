// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

Future<String?> captureLaptopWebcamPhoto({bool isTamil = true}) async {
  final completer = Completer<String?>();

  try {
    final nav = html.window.navigator;
    if (nav.mediaDevices == null) {
      completer.complete(null);
      return completer.future;
    }

    final mediaStream = await nav.mediaDevices!.getUserMedia({
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      },
      'audio': false,
    });

    // Create Modal Overlay
    final overlay = html.DivElement()
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100vw'
      ..style.height = '100vh'
      ..style.backgroundColor = 'rgba(0, 0, 0, 0.75)'
      ..style.zIndex = '999999'
      ..style.display = 'flex'
      ..style.flexDirection = 'column'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.padding = '16px'
      ..style.boxSizing = 'border-box'
      ..style.fontFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';

    final card = html.DivElement()
      ..style.backgroundColor = '#ffffff'
      ..style.borderRadius = '14px'
      ..style.overflow = 'hidden'
      ..style.boxShadow = '0 12px 36px rgba(0,0,0,0.5)'
      ..style.maxWidth = '520px'
      ..style.width = '100%'
      ..style.display = 'flex'
      ..style.flexDirection = 'column';

    // Header
    final header = html.DivElement()
      ..style.padding = '12px 18px'
      ..style.backgroundColor = '#1565C0'
      ..style.color = '#ffffff'
      ..style.display = 'flex'
      ..style.justifyContent = 'space-between'
      ..style.alignItems = 'center'
      ..style.fontWeight = 'bold'
      ..style.fontSize = '15px';

    final titleSpan = html.SpanElement()
      ..innerText = isTamil ? '📷 மடிக்கணினி கேமரா (Laptop Camera)' : '📷 Laptop Webcam Preview';

    final closeBtn = html.ButtonElement()
      ..innerText = '✕'
      ..style.background = 'transparent'
      ..style.border = 'none'
      ..style.color = '#ffffff'
      ..style.fontSize = '18px'
      ..style.cursor = 'pointer';

    header.children.addAll([titleSpan, closeBtn]);

    // Video Container
    final videoContainer = html.DivElement()
      ..style.position = 'relative'
      ..style.backgroundColor = '#000000'
      ..style.aspectRatio = '4/3'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.overflow = 'hidden';

    final video = html.VideoElement()
      ..autoplay = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.transform = 'scaleX(-1)'; // Mirror for natural selfie preview

    video.srcObject = mediaStream;
    videoContainer.children.add(video);

    // Controls
    final controls = html.DivElement()
      ..style.padding = '14px 18px'
      ..style.display = 'flex'
      ..style.justifyContent = 'space-between'
      ..style.alignItems = 'center'
      ..style.backgroundColor = '#F5F5F5';

    final cancelBtn = html.ButtonElement()
      ..innerText = isTamil ? 'ரத்து செய் (Cancel)' : 'Cancel'
      ..style.padding = '10px 18px'
      ..style.borderRadius = '8px'
      ..style.border = '1px solid #ccc'
      ..style.backgroundColor = '#ffffff'
      ..style.color = '#333333'
      ..style.cursor = 'pointer'
      ..style.fontWeight = 'bold'
      ..style.fontSize = '13px';

    final snapBtn = html.ButtonElement()
      ..innerText = isTamil ? '📸 படம் எடு (Capture)' : '📸 Capture Photo'
      ..style.padding = '10px 22px'
      ..style.borderRadius = '8px'
      ..style.border = 'none'
      ..style.backgroundColor = '#2E7D32'
      ..style.color = '#ffffff'
      ..style.cursor = 'pointer'
      ..style.fontWeight = 'bold'
      ..style.fontSize = '14px'
      ..style.boxShadow = '0 3px 8px rgba(46,125,50,0.3)';

    controls.children.addAll([cancelBtn, snapBtn]);

    card.children.addAll([header, videoContainer, controls]);
    overlay.children.add(card);
    html.document.body?.children.add(overlay);

    void cleanup() {
      try {
        for (final track in mediaStream.getTracks()) {
          track.stop();
        }
      } catch (_) {}
      overlay.remove();
    }

    closeBtn.onClick.listen((_) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    });

    cancelBtn.onClick.listen((_) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    });

    snapBtn.onClick.listen((_) {
      final canvas = html.CanvasElement(
        width: video.videoWidth > 0 ? video.videoWidth : 640,
        height: video.videoHeight > 0 ? video.videoHeight : 480,
      );
      final ctx = canvas.context2D;
      // Mirror back for true photo
      ctx.translate(canvas.width!, 0);
      ctx.scale(-1, 1);
      ctx.drawImage(video, 0, 0);

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
      cleanup();
      if (!completer.isCompleted) completer.complete(dataUrl);
    });
  } catch (e) {
    if (!completer.isCompleted) completer.complete(null);
  }

  return completer.future;
}
