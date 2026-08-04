import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Longest edge the app will ever need for style generation. Anything larger
/// is downscaled before upload.
const int kMaxUploadDimension = 2048;

/// Decodes arbitrary picked-photo bytes and re-encodes them as a standard
/// JPEG with **no EXIF metadata**.
///
/// SEC-8.3. Both upload paths used to decode and re-encode already, and it was
/// assumed that alone dropped metadata. It does not: `img.encodeJpg` writes the
/// EXIF block back out whenever the image carries one, and `copyResize` clones
/// it onto the resized copy, so a decode/resize/encode round trip preserves
/// every tag. What reaches the servers today includes the handset's exact
/// firmware build, the capture timestamp, the user's UTC offset and a
/// per-photo device ImageUniqueID - and GPS coordinates whenever the
/// photographer had location tagging on, because image_picker's ExifDataCopier
/// deliberately copies all 32 GPS tags through its own resize.
///
/// The backend strips metadata again on the paths it can see, and that server
/// side is the enforceable control - an old install keeps sending whatever it
/// always sent. This exists for the one path the backend never sees (the avatar
/// upload goes straight from the app to Supabase Storage), and because there is
/// no reason to put a user's location on the wire at all when we can drop it
/// before it leaves the phone.
///
/// [maxDimension] downscales the longest edge when given; pass null to keep the
/// picked resolution. Returns null if the bytes don't decode as an image -
/// a corrupt file, or a format the `image` package can't read (some HEIC
/// variants) - so callers can reject the photo rather than hand something
/// undecodable to the preview or the upload.
Uint8List? normalizeImageBytes(
  Uint8List bytes, {
  int? maxDimension,
  int quality = 90,
}) {
  // decodeImage returns null for bytes it doesn't recognise, but throws for
  // some malformed inputs (an empty file raises RangeError from the PNG
  // sniffer before any decoder is chosen). Callers treat null as "reject this
  // photo", so both failure shapes are funnelled into it here rather than
  // leaving one of them to surface as an unhandled isolate error.
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;

  // A note on rotation, because getting this wrong is invisible in code review
  // and obvious to every user: orientation lives in the EXIF that is about to
  // be deleted, so if the pixels were still unrotated at that point, every
  // portrait phone photo would come out sideways. There is no explicit
  // `bakeOrientation` call here because `decodeImage` already applies the
  // orientation and clears the tag while decoding - verified against a JPEG
  // carrying an unbaked orientation, not assumed. Calling it anyway would copy
  // the whole image for nothing. The end-to-end behaviour is pinned by a test
  // built on that same fixture, so if a future version of `image` stops doing
  // this, the test fails instead of the photos.
  var normalized = decoded;
  if (maxDimension != null) {
    final longestSide =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longestSide > maxDimension) {
      normalized = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? maxDimension : null,
        height: decoded.height > decoded.width ? maxDimension : null,
      );
    }
  }

  // The actual fix. `normalized` is either the freshly decoded image or a
  // resized copy of it - never anything the caller holds a reference to - so
  // clearing in place is safe.
  normalized.exif.clear();

  return Uint8List.fromList(img.encodeJpg(normalized, quality: quality));
}
