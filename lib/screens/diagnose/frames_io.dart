import 'dart:typed_data';

import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';

/// Samples still frames from a video so the AI can look at it.
/// Video itself is never uploaded; only up to [count] JPEG frames.
Future<List<Uint8List>> extractFrames(XFile video, {int count = 6}) async {
  const times = [0, 1000, 2500, 4000, 6000, 8000, 11000, 15000];
  final frames = <Uint8List>[];
  int? lastLen;
  for (final t in times) {
    if (frames.length >= count) break;
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: video.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 1280,
        timeMs: t,
        quality: 80,
      );
      // Past the end of a short clip the plugin keeps returning the last frame.
      if (bytes.isEmpty || bytes.length == lastLen) continue;
      lastLen = bytes.length;
      frames.add(bytes);
    } catch (_) {
      // Beyond the video's duration on some platforms.
    }
  }
  return frames;
}
