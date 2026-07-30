import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/auth_service.dart';
import '../services/network_client.dart';

/// SEC-8.1B-2 (step 2) — makes the client indifferent to the *form* a
/// creation's image URL takes.
///
/// Today every creation URL is a raw public Supabase object URL, fetched with
/// no credentials. The migration will replace those with stable backend URLs
/// that require an Authorization header, and the point of this file is that
/// the swap needs no further client release: the app already sends credentials
/// when (and only when) the URL is ours, and already caches by an identity
/// that does not change when the URL does.
///
/// Nothing here changes current behaviour. Against today's Supabase URLs
/// [isBackendImageUrl] is false, so no header is attached and the request goes
/// out exactly as it does now.

/// True when [url] points at our own backend, and is therefore a URL we may
/// attach the user's access token to.
///
/// Origin-scoped on purpose, and this is the security-relevant part of the
/// file. The token must never be sent anywhere except our own API - not to
/// Supabase Storage, not to a provider CDN, not to whatever a future API
/// response happens to contain. A prefix match on the base URL alone would be
/// too loose (`https://api.styli.ai.evil.com/...` starts with nothing useful,
/// but `https://api.styli.ai@evil.com/...` is a real trick), so the comparison
/// is on the parsed origin: scheme, host and port must all match.
bool isBackendImageUrl(String url) {
  final backend = Uri.tryParse(backendBaseUrl());
  final target = Uri.tryParse(url);
  if (backend == null || target == null) return false;
  if (!target.hasScheme || !target.hasAuthority) return false;

  return target.scheme == backend.scheme &&
      target.host == backend.host &&
      target.port == backend.port;
}

/// The backend origin, read the same way ApiService reads it.
String backendBaseUrl() {
  try {
    return dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
  } catch (_) {
    // dotenv throws if it was never initialised (some test entrypoints).
    return 'http://localhost:3000';
  }
}

/// Headers to send when fetching [url] as an image.
///
/// Empty for anything that is not ours, which is every creation URL today.
/// For a backend URL it carries the Bearer token, reusing
/// [AuthorizedHttpClient.headers] so image requests inherit the same
/// proactive session refresh every other authorized call already performs -
/// a second token path would eventually drift from it.
///
/// `Content-Type` is stripped: these are GETs with no body, and sending one
/// on an image fetch is meaningless.
Future<Map<String, String>> imageAuthHeaders(String url) async {
  if (!isBackendImageUrl(url)) return const {};

  final headers = await AuthorizedHttpClient(AuthService()).headers();
  headers.remove('Content-Type');
  return headers;
}

/// A cache key that survives the URL changing underneath it.
///
/// `CachedNetworkImage` keys its disk and memory caches on the URL string by
/// default. That is fine while URLs are permanent, and actively harmful the
/// moment they are not: the day delivery moves to backend URLs, every cached
/// image would be orphaned and silently re-downloaded, and - worse - a device
/// holding a now-dead public URL would render nothing at all, because the
/// bytes it already has are filed under a key nobody asks for any more.
///
/// Keying on the creation instead makes the cache outlive any URL change, so
/// the same bytes keep serving the same picture before, during and after the
/// bucket flip, including offline.
String creationCacheKey(String creationId, {required bool thumbnail}) =>
    'creation:$creationId:${thumbnail ? 'thumb' : 'original'}';

/// The address to actually render for a profile's stored `avatar_url`.
///
/// R-2 phase 4. The `avatars` bucket is private, so a stored Supabase object
/// URL is no longer fetchable and must be replaced by our own authenticated
/// endpoint, which authorizes the caller and redirects to a short-lived signed
/// URL. There is no user id in that address: a caller can only ever request
/// their own avatar, so there is nothing to enumerate.
///
/// Anything that is not one of our storage objects is returned unchanged. That
/// is the majority of production data - most accounts carry a Google OAuth
/// picture on a googleusercontent.com host, which is public, is not ours to
/// sign, and must keep rendering exactly as it does today.
///
/// The `?v=<timestamp>` cache-buster is carried across rather than dropped.
/// The endpoint's address is otherwise identical for every upload, so without
/// it the image layer would keep serving the previous avatar from cache - the
/// same reason the buster exists on the storage URL.
String? avatarDisplayUrl(String? storedUrl) {
  if (storedUrl == null || storedUrl.trim().isEmpty) return null;

  final parsed = Uri.tryParse(storedUrl);
  if (parsed == null || !parsed.hasScheme) return storedUrl;

  final isOurAvatarObject =
      parsed.path.contains('/storage/v1/object/') && parsed.path.contains('/avatars/');
  if (!isOurAvatarObject) return storedUrl;

  final version = parsed.queryParameters['v'];
  final base = '${backendBaseUrl()}/api/profile/avatar';
  return version == null || version.isEmpty ? base : '$base?v=$version';
}

/// Resolves [imageAuthHeaders] before handing off to [builder].
///
/// The asynchronous step exists only for URLs that need credentials, so this
/// short-circuits for everything else: today no creation URL is ours, so
/// [builder] is invoked synchronously with no headers and the widget tree is
/// exactly what it was before this file existed. No FutureBuilder, no extra
/// rebuild, no placeholder frame.
class AuthorizedImage extends StatelessWidget {
  final String url;
  final Widget Function(Map<String, String>? headers) builder;

  const AuthorizedImage({super.key, required this.url, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (!isBackendImageUrl(url)) return builder(null);

    return FutureBuilder<Map<String, String>>(
      future: imageAuthHeaders(url),
      builder: (context, snapshot) {
        // Until the token resolves there is nothing useful to request. The
        // cached copy, if there is one, is served by the image layer as soon
        // as it is built, so this frame is only ever seen on a cold cache.
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return builder(snapshot.data);
      },
    );
  }
}
