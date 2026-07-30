import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/utils/gallery_saver.dart';
import 'package:prombt_app/utils/image_delivery.dart';
import 'package:prombt_app/data/creations_manager.dart';

/// SEC-8.1B-2 (step 2) — the client is tolerant of both URL forms.
///
/// Today every creation URL is a raw public Supabase object URL. These tests
/// pin the two properties that let delivery move behind the backend without
/// another client release: credentials are attached to our own URLs and only
/// ours, and the image cache is keyed by something that does not change when
/// the URL does.
///
/// dotenv is not initialised under `flutter test`, so [backendBaseUrl] falls
/// back to http://localhost:3000 — that is the "our backend" origin here.
void main() {
  const publicSupabaseUrl =
      'https://proj.supabase.co/storage/v1/object/public/creations/original/abc.webp';
  const backendUrl = 'http://localhost:3000/api/creations/c-1/image';

  group('isBackendImageUrl', () {
    test('is false for the public Supabase URLs used today', () {
      expect(isBackendImageUrl(publicSupabaseUrl), isFalse);
    });

    test('is true for a URL on our own origin', () {
      expect(isBackendImageUrl(backendUrl), isTrue);
    });

    test('is false for a third-party URL', () {
      expect(isBackendImageUrl('https://fal.media/files/abc.jpg'), isFalse);
      expect(isBackendImageUrl('https://lh3.googleusercontent.com/a/x=s96-c'), isFalse);
    });

    test('is not fooled by a host that merely starts the same', () {
      // A prefix match on the base URL would accept this and hand the user's
      // access token to somebody else's server.
      expect(isBackendImageUrl('http://localhost:3000.evil.com/x.jpg'), isFalse);
    });

    test('is not fooled by userinfo in the authority', () {
      // http://localhost:3000@evil.com/ has host evil.com, not localhost.
      expect(isBackendImageUrl('http://localhost:3000@evil.com/x.jpg'), isFalse);
    });

    test('distinguishes scheme and port', () {
      expect(isBackendImageUrl('https://localhost:3000/api/x'), isFalse);
      expect(isBackendImageUrl('http://localhost:3001/api/x'), isFalse);
    });

    test('is false for non-http values, including asset paths', () {
      expect(isBackendImageUrl('assets/images/sample.png'), isFalse);
      expect(isBackendImageUrl(''), isFalse);
      expect(isBackendImageUrl('not a url at all'), isFalse);
    });
  });

  group('imageAuthHeaders', () {
    test('sends nothing at all for a public URL', () async {
      // The security property: the access token must never leave our origin.
      // This also means today's behaviour is byte-for-byte unchanged, since
      // every creation URL is currently public.
      expect(await imageAuthHeaders(publicSupabaseUrl), isEmpty);
    });

    test('sends nothing for a third-party URL', () async {
      expect(await imageAuthHeaders('https://fal.media/files/abc.jpg'), isEmpty);
    });

    test('sends nothing for an asset path', () async {
      expect(await imageAuthHeaders('assets/images/sample.png'), isEmpty);
    });
  });

  group('creationCacheKey', () {
    test('is stable for the same creation regardless of URL', () {
      // The whole point: the key is derived from the creation, so the cached
      // bytes survive the URL changing form during the migration.
      final before = creationCacheKey('c-1', thumbnail: false);
      final after = creationCacheKey('c-1', thumbnail: false);

      expect(before, equals(after));
      expect(before, isNot(contains('supabase')));
      expect(before, isNot(contains('http')));
    });

    test('separates the thumbnail from the original', () {
      // Sharing one key would make the grid thumbnail and the full-screen
      // original evict each other.
      expect(
        creationCacheKey('c-1', thumbnail: true),
        isNot(equals(creationCacheKey('c-1', thumbnail: false))),
      );
    });

    test('separates different creations', () {
      expect(
        creationCacheKey('c-1', thumbnail: true),
        isNot(equals(creationCacheKey('c-2', thumbnail: true))),
      );
    });
  });

  group('mimeTypeFor', () {
    test('still reads the extension when there is no server type', () {
      expect(GallerySaver.mimeTypeFor('/a/b.webp'), 'image/webp');
      expect(GallerySaver.mimeTypeFor('/a/b.png'), 'image/png');
      expect(GallerySaver.mimeTypeFor('/a/b.jpg'), 'image/jpeg');
      expect(GallerySaver.mimeTypeFor('/a/b.webp?v=1'), 'image/webp');
    });

    test('prefers what the server said', () {
      // A stable backend URL carries no extension to guess from, so without
      // this every share would be labelled JPEG.
      expect(
        GallerySaver.mimeTypeFor(
          'http://localhost:3000/api/creations/c-1/image',
          serverContentType: 'image/webp',
        ),
        'image/webp',
      );
    });

    test('tolerates charset parameters and casing', () {
      expect(
        GallerySaver.mimeTypeFor('/a/b', serverContentType: 'IMAGE/PNG; charset=binary'),
        'image/png',
      );
    });

    test('ignores a non-image server type and falls back', () {
      // An error page or a proxy's text/html must not become the share type.
      expect(
        GallerySaver.mimeTypeFor('/a/b.webp', serverContentType: 'text/html'),
        'image/webp',
      );
    });
  });

  group('legacy persisted creations still load', () {
    test('parses the local JSON shape (imagePath)', () {
      final item = CreationItem.fromJson({
        'id': 'c-1',
        'styleName': 'Vintage',
        'imagePath': publicSupabaseUrl,
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(item.imagePath, publicSupabaseUrl);
      expect(item.displayThumbnail, publicSupabaseUrl);
    });

    test('parses the API shape (imageUrl) and a thumbnail', () {
      final item = CreationItem.fromJson({
        'id': 'c-2',
        'styleName': 'Vintage',
        'imageUrl': publicSupabaseUrl,
        'thumbnailUrl': 'https://proj.supabase.co/storage/v1/object/public/creations/thumbs/abc.webp',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(item.imagePath, publicSupabaseUrl);
      expect(item.displayThumbnail, contains('/thumbs/'));
    });

    test('parses a future backend delivery URL just as happily', () {
      // Nothing in the model needs to change when delivery moves.
      final item = CreationItem.fromJson({
        'id': 'c-3',
        'styleName': 'Vintage',
        'imageUrl': backendUrl,
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(item.imagePath, backendUrl);
      expect(isBackendImageUrl(item.imagePath), isTrue);
    });

    test('a legacy bundled-asset creation is never treated as ours', () {
      final item = CreationItem.fromJson({
        'id': 'c-4',
        'styleName': 'Vintage',
        'imagePath': 'assets/images/sample.png',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      // It must stay migratable, and must never receive an auth header.
      expect(isBackendImageUrl(item.imagePath), isFalse);
    });
  });

  group('avatarDisplayUrl', () {
    // R-2 phase 4. The avatars bucket is private, so a stored object URL is no
    // longer fetchable and must be replaced by our authenticated endpoint.
    const storedAvatar =
        'https://proj.supabase.co/storage/v1/object/public/avatars/f60f71b5.jpg?v=1784034159601';
    const googlePicture = 'https://lh3.googleusercontent.com/a/ACg8ocI7kTt=s96-c';

    test('routes one of our avatar objects to the backend endpoint', () {
      expect(
        avatarDisplayUrl(storedAvatar),
        'http://localhost:3000/api/profile/avatar?v=1784034159601',
      );
    });

    test('carries the cache-buster across, so a new upload actually shows', () {
      // The endpoint address is identical for every upload, so without this the
      // image layer would keep serving the previous avatar from cache.
      final first = avatarDisplayUrl(
          'https://proj.supabase.co/storage/v1/object/public/avatars/u.jpg?v=1');
      final second = avatarDisplayUrl(
          'https://proj.supabase.co/storage/v1/object/public/avatars/u.jpg?v=2');

      expect(first, isNot(equals(second)));
      expect(first, contains('?v=1'));
      expect(second, contains('?v=2'));
    });

    test('never leaks a storage URL to the image layer', () {
      expect(avatarDisplayUrl(storedAvatar), isNot(contains('/object/public/')));
      expect(avatarDisplayUrl(storedAvatar), isNot(contains('supabase')));
    });

    test('is on our own origin, so credentials are attached', () {
      // The endpoint requires a Bearer token; isBackendImageUrl is what decides
      // whether one is sent, so the rewritten URL has to satisfy it.
      expect(isBackendImageUrl(avatarDisplayUrl(storedAvatar)!), isTrue);
    });

    test('handles a stored avatar with no cache-buster', () {
      expect(
        avatarDisplayUrl('https://proj.supabase.co/storage/v1/object/public/avatars/u.jpg'),
        'http://localhost:3000/api/profile/avatar',
      );
    });

    test('leaves a Google provider picture untouched', () {
      // The majority of production accounts. Public, not ours to sign, and it
      // must keep rendering exactly as before - with no token attached.
      expect(avatarDisplayUrl(googlePicture), googlePicture);
      expect(isBackendImageUrl(googlePicture), isFalse);
    });

    test('returns null for a missing or blank avatar', () {
      expect(avatarDisplayUrl(null), isNull);
      expect(avatarDisplayUrl(''), isNull);
      expect(avatarDisplayUrl('   '), isNull);
    });

    test('leaves an unrelated storage object alone', () {
      // Only avatars moved behind this endpoint; a creation URL is handled by
      // its own delivery path and must not be rewritten here.
      const creation =
          'https://proj.supabase.co/storage/v1/object/public/creations/original/abc.webp';

      expect(avatarDisplayUrl(creation), creation);
    });
  });
}
