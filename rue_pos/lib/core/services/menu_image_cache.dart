// lib/core/services/menu_image_cache.dart
//
// Disk-persistent menu image cache.
//
// - Images are stored on disk via flutter_cache_manager, so they survive
//   app restarts and are available offline.
// - Rendering uses Flutter's built-in Image widget with
//   CachedNetworkImageProvider so that in-memory cache hits render
//   SYNCHRONOUSLY on mount — no placeholder flash or fade-in when
//   switching categories / remounting cards.
// - Stale period is 1 year; the cache is only evicted when
//   [MenuImageCache.invalidate] is called — typically on a forced menu
//   refresh / sync.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cache manager dedicated to menu images. Lives in its own on-disk
/// directory so clearing it doesn't touch other cached files in the app.
class MenuImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'rue_menu_images';
  static final MenuImageCacheManager _instance = MenuImageCacheManager._();
  factory MenuImageCacheManager() => _instance;

  MenuImageCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 365),
          maxNrOfCacheObjects: 500,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ));
}

class MenuImageCache {
  MenuImageCache(this._manager);
  final MenuImageCacheManager _manager;

  /// Ensure each URL is downloaded to disk. Safe to call repeatedly —
  /// already-cached URLs return immediately with no network call. Call
  /// after a fresh menu load so the order screen renders instantly and
  /// is ready offline on next app launch.
  Future<void> warmUp(Iterable<String> urls) async {
    await Future.wait(
      urls.map((u) async {
        try {
          await _manager.getSingleFile(u);
        } catch (_) {
          // Swallow per-URL failures so one bad image doesn't abort warm-up.
        }
      }),
    );
  }

  /// Wipe the disk + in-memory caches. Call on a forced menu refresh so
  /// the next render refetches fresh images from the server.
  Future<void> invalidate() async {
    await _manager.emptyCache();
    // Also clear Flutter's in-memory ImageCache so currently-decoded
    // frames are dropped and next mount refetches.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Evict a single URL (e.g. when one item's image changed).
  Future<void> evict(String url) async {
    await _manager.removeFile(url);
    await CachedNetworkImageProvider(url, cacheManager: _manager).evict();
  }
}

final menuImageCacheProvider = Provider<MenuImageCache>((ref) {
  return MenuImageCache(MenuImageCacheManager());
});

/// Drop-in replacement for Image.network for menu item images.
///
/// - On first load in a session: fetches from disk cache (or network if
///   not yet cached), shows placeholder while loading, no fade animation.
/// - On subsequent mounts (category switch, scroll recycle, etc.): renders
///   synchronously from Flutter's in-memory image cache — zero flicker.
class MenuImage extends StatelessWidget {
  const MenuImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: CachedNetworkImageProvider(
        url,
        cacheManager: MenuImageCacheManager(),
      ),
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // Cache hit on mount — render immediately, no placeholder flash.
        if (wasSynchronouslyLoaded) return child;
        // First decode complete — swap to the image, no animation.
        if (frame != null) return child;
        // Still loading from disk / network.
        return SizedBox(
          width: width,
          height: height,
          child: placeholder ?? _defaultPlaceholder(),
        );
      },
      errorBuilder: (context, error, stack) => SizedBox(
        width: width,
        height: height,
        child: errorWidget ?? _defaultError(),
      ),
    );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _defaultPlaceholder() => const ColoredBox(
        color: Color(0x11000000),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _defaultError() => const ColoredBox(
        color: Color(0x11000000),
        child: Center(
          child: Icon(Icons.image_not_supported_outlined,
              size: 24, color: Colors.black38),
        ),
      );
}