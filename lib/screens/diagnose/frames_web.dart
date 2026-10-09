import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

/// Samples still frames from a video in the browser (video element + canvas).
Future<List<Uint8List>> extractFrames(XFile file, {int count = 6}) async {
  final video = web.HTMLVideoElement()
    ..muted = true
    ..preload = 'auto'
    ..src = file.path;
  video.setAttribute('playsinline', 'true');

  await video.onLoadedData.first.timeout(const Duration(seconds: 20));
  var duration = video.duration;
  if (duration.isNaN || duration.isInfinite || duration <= 0) duration = 10;

  final scale = video.videoWidth > 1280 ? 1280 / video.videoWidth : 1.0;
  final w = (video.videoWidth * scale).round(), h = (video.videoHeight * scale).round();
  if (w == 0 || h == 0) throw Exception('This video format is not supported by your browser.');
  final canvas = web.HTMLCanvasElement()
    ..width = w
    ..height = h;
  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;

  final n = duration < 2 ? 1 : count;
  final frames = <Uint8List>[];
  for (var i = 0; i < n; i++) {
    final t = n == 1 ? 0.0 : (duration * (i + 0.5) / n).clamp(0.0, duration - 0.05);
    final seeked = video.onSeeked.first;
    video.currentTime = t;
    await seeked.timeout(const Duration(seconds: 10));
    ctx.drawImage(video, 0, 0, w, h);
    final url = canvas.toDataURL('image/jpeg', 0.8.toJS);
    frames.add(base64Decode(url.substring(url.indexOf(',') + 1)));
  }
  video.removeAttribute('src');
  video.load();
  return frames;
}
