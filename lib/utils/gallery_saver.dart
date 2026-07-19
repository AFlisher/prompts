import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';

class GallerySaver {
  /// Loads raw bytes for either a bundled asset key or an http(s) URL - the
  /// same asset-vs-network dispatch every image in the app uses (see
  /// utils/image_helper.dart's buildStyleImage). Returns null on any
  /// failure instead of throwing, so callers can show one generic error.
  static Future<Uint8List?> loadBytes(String path) async {
    try {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        final response = await http.get(Uri.parse(path));
        if (response.statusCode != 200) return null;
        return response.bodyBytes;
      }
      final byteData = await rootBundle.load(path);
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error loading image bytes for "$path": $e');
      return null;
    }
  }

  /// Best-effort MIME type from a path/URL's file extension, for the
  /// occasions (e.g. sharing) that need one. Defaults to JPEG.
  static String mimeTypeFor(String path) {
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
