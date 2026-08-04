import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';
import '../services/network_client.dart';
import 'image_delivery.dart';

/// Bytes plus whatever the server said they were.
///
/// SEC-8.1B-2: the content type used to be guessed from the URL's extension,
/// which works for `.../original/abc.webp` and not at all for a stable backend
/// URL like `.../creations/<id>/image`. When the server states a type, that is
/// authoritative; the extension guess stays as the fallback.
class LoadedImageBytes {
  final Uint8List bytes;
  final String? contentType;

  const LoadedImageBytes(this.bytes, this.contentType);
}

class GallerySaver {
  /// Loads raw bytes for either a bundled asset key or an http(s) URL - the
  /// same asset-vs-network dispatch every image in the app uses (see
  /// utils/image_helper.dart's buildStyleImage). Returns null on any
  /// failure instead of throwing, so callers can show one generic error.
  static Future<Uint8List?> loadBytes(String path) async {
    return (await loadImageBytes(path))?.bytes;
  }

  /// [loadBytes] plus the server-reported content type.
  ///
  /// SEC-8.1B-2: credentials are attached automatically when - and only when -
  /// the URL is one of ours (see [imageAuthHeaders]). Today that is never true
  /// for a creation, so this sends exactly the same unauthenticated request it
  /// always has; after delivery moves behind the backend it starts sending the
  /// Bearer token without this call site changing again. Downloading and
  /// sharing are the two paths that would otherwise start returning 401 the
  /// day the bucket is flipped, because they bypass the image widget entirely.
  static Future<LoadedImageBytes?> loadImageBytes(String path) async {
    try {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        final headers = await imageAuthHeaders(path);
        final response = await http
            .get(Uri.parse(path), headers: headers.isEmpty ? null : headers)
            .timeout(
              NetworkTimeouts.api,
              onTimeout: () => throw TimeoutException('Image download timed out'),
            );
        if (response.statusCode != 200) return null;
        return LoadedImageBytes(
          response.bodyBytes,
          response.headers['content-type'],
        );
      }
      final byteData = await rootBundle.load(path);
      return LoadedImageBytes(byteData.buffer.asUint8List(), null);
    } catch (e) {
      debugPrint('Error loading image bytes for "$path": $e');
      return null;
    }
  }

  /// Best-effort MIME type from a path/URL's file extension, for the
  /// occasions (e.g. sharing) that need one. Defaults to JPEG.
  ///
  /// [serverContentType] wins when present: a stable backend image URL carries
  /// no extension to read, so the extension guess would silently label every
  /// share as JPEG.
  static String mimeTypeFor(String path, {String? serverContentType}) {
    final declared = serverContentType?.split(';').first.trim().toLowerCase();
    if (declared != null && declared.startsWith('image/')) return declared;

    final clean = path.split('?').first.toLowerCase();
    if (clean.endsWith('.webp')) return 'image/webp';
    if (clean.endsWith('.png')) return 'image/png';
    if (clean.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  /// Re-encodes to PNG before handing bytes to the native gallery writer.
  ///
  /// gal's Android side sniffs the format itself (Apache Commons Imaging)
  /// to pick a file extension, and doesn't recognize WebP - Stability AI's
  /// output format - which throws GalException/UNEXPECTED for every
  /// Stability-generated image (confirmed via on-device logcat: bytes fetch
  /// succeeds, Gal.putImageBytes itself throws). Re-encoding through the
  /// `image` package (already decodes WebP) guarantees a format gal always
  /// recognizes, regardless of source. Falls back to the original bytes if
  /// decoding fails, so this never turns a working save into a failure.
  static Uint8List _ensureGalleryCompatible(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      return Uint8List.fromList(img.encodePng(decoded));
    } catch (e) {
      debugPrint('Could not re-encode image for gallery save, using original bytes: $e');
      return bytes;
    }
  }

  /// Saves an image (from assets, a network URL, or a local file) to the
  /// user's native system photo library/gallery.
  /// Returns a success status description on success, or null on failure.
  static Future<String?> saveImage({
    String? assetPath,
    String? filePath,
  }) async {
    try {
      Uint8List bytes;
      String fileName = 'StyliAI_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (assetPath != null) {
        final loaded = await loadBytes(assetPath);
        if (loaded == null) return null;
        bytes = _ensureGalleryCompatible(loaded);
      } else if (filePath != null) {
        final file = File(filePath);
        if (!await file.exists()) return null;
        bytes = await file.readAsBytes();
        fileName = file.uri.pathSegments.last;
      } else {
        return null;
      }

      // Bypass native method channels during unit/widget tests
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return '/mock/storage/StyliAI/$fileName';
      }

      // Natively save to the gallery using gal package
      await Gal.putImageBytes(bytes);

      return 'StyliAI Gallery';
    } catch (e) {
      debugPrint('Error saving image to gallery: $e');
      return null;
    }
  }
}
