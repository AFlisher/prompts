import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:prombt_app/services/profile_service.dart';

/// R-2 — an avatar that cannot be normalised must be refused, not uploaded raw.
///
/// The regression these guard against had the worst possible shape: the
/// fallback fired precisely when normalisation failed, so the only case where
/// validation mattered was the one case that skipped it — and skipped SEC-8.3's
/// metadata stripping along with it. Nothing on the server would have caught
/// it, because the avatars bucket checks the client's own declared
/// Content-Type and the object's name, never its content.
void main() {
  final exifMarker = Uint8List.fromList([0x45, 0x78, 0x69, 0x66, 0x00, 0x00]);

  bool containsBytes(Uint8List haystack, Uint8List needle) {
    if (needle.length > haystack.length) return false;
    for (var i = 0; i <= haystack.length - needle.length; i++) {
      var match = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }

  Uint8List jpegWithExif() {
    final image = img.Image(width: 48, height: 48);
    img.fill(image, color: img.ColorRgb8(120, 90, 200));
    image.exif.imageIfd['Software'] = 'StyliTestSoftware';
    image.exif.gpsIfd['GPSLatitudeRef'] = 'N';
    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }

  group('avatarUploadBytes', () {
    test('returns a decodable JPEG for a real photo', () {
      final out = avatarUploadBytes(jpegWithExif());

      final decoded = img.decodeImage(out);
      expect(decoded, isNotNull);
      expect(decoded!.width, 48);
      expect(decoded.height, 48);
    });

    test('strips the metadata before upload', () {
      final out = avatarUploadBytes(jpegWithExif());

      expect(containsBytes(out, exifMarker), isFalse);
      expect(
        containsBytes(out, Uint8List.fromList('StyliTestSoftware'.codeUnits)),
        isFalse,
      );
    });

    test('never returns the input unchanged', () {
      // The old fallback uploaded the picked file verbatim. Returning the input
      // is therefore the specific failure worth naming.
      final input = jpegWithExif();

      final out = avatarUploadBytes(input);

      expect(out, isNot(same(input)));
    });

    test('throws for bytes that are not an image', () {
      expect(
        () => avatarUploadBytes(Uint8List.fromList('not an image'.codeUnits)),
        throwsA(isA<Exception>()),
      );
    });

    test('throws for empty bytes', () {
      expect(() => avatarUploadBytes(Uint8List(0)), throwsA(isA<Exception>()));
    });

    test('throws for a truncated JPEG', () {
      final truncated = Uint8List.sublistView(jpegWithExif(), 0, 20);

      expect(() => avatarUploadBytes(truncated), throwsA(isA<Exception>()));
    });

    test('throws for a file that only pretends to be a JPEG', () {
      // A JPEG magic number in front of arbitrary content: this is exactly what
      // a header-only check would wave through, and what a decode rejects.
      final fake = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, // JPEG SOI + APP0
        ...'this is not actually an image'.codeUnits,
      ]);

      expect(() => avatarUploadBytes(fake), throwsA(isA<Exception>()));
    });

    test('the refusal carries a message a user can act on', () {
      // It reaches the user through the edit-profile screen's generic
      // "Failed to save profile: $e" snackbar.
      expect(
        () => avatarUploadBytes(Uint8List(0)),
        throwsA(
          predicate(
            (e) => e.toString().contains('choose a different one'),
            'has an actionable message',
          ),
        ),
      );
    });
  });
}
