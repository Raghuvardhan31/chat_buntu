import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chataway_plus/core/sync/authenticated_image_cache_manager.dart';
import 'package:chataway_plus/core/constants/api_url/api_urls.dart';
import 'package:chataway_plus/core/connectivity/connectivity_service.dart';

/// WHATSAPP-STYLE: Cached circle avatar optimized for millions of users
/// - Uses cached connectivity state (no async delays)
/// - Prioritizes local cache (instant display)
/// - Background refresh when stale
/// - Graceful fallback to default icon
class CachedCircleAvatar extends StatefulWidget {
  final String? chatPictureUrl;
  final String? chatPictureVersion;
  final double radius;
  final Color backgroundColor;
  final Color iconColor;
  final String? contactName;

  const CachedCircleAvatar({
    super.key,
    required this.chatPictureUrl,
    this.chatPictureVersion,
    required this.radius,
    required this.backgroundColor,
    required this.iconColor,
    this.contactName,
  });

  // Deterministic color palette for initials avatars
  static const List<Color> _avatarColors = [
    Color(0xFF1ABC9C), // Turquoise
    Color(0xFF2ECC71), // Emerald
    Color(0xFF3498DB), // Peter River
    Color(0xFF9B59B6), // Amethyst
    Color(0xFFE67E22), // Carrot
    Color(0xFFE74C3C), // Alizarin
    Color(0xFF1E88E5), // Blue
    Color(0xFF00ACC1), // Cyan
    Color(0xFF43A047), // Green
    Color(0xFF8E24AA), // Purple
    Color(0xFFF4511E), // Deep Orange
    Color(0xFF6D4C41), // Brown
    Color(0xFF546E7A), // Blue Grey
    Color(0xFFD81B60), // Pink
    Color(0xFF00897B), // Teal
    Color(0xFFFF8F00), // Amber
  ];

  /// Get initials from a contact name (1-2 characters)
  static String getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  /// Get a deterministic color based on the contact name
  static Color getColorForName(String name) {
    final hash = name.trim().toLowerCase().codeUnits.fold<int>(
      0,
      (h, c) => h + c,
    );
    return _avatarColors[hash % _avatarColors.length];
  }

  @override
  State<CachedCircleAvatar> createState() => _CachedCircleAvatarState();
}

class _CachedCircleAvatarState extends State<CachedCircleAvatar> {
  String? _imagePath; // Local file path - works offline!
  String? _baseUrl;
  String? _fullUrl; // Pre-constructed full URL for consistent cache key

  @override
  void initState() {
    super.initState();
    _constructFullUrl();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptLoadCachedImage();
    });
  }

  @override
  void didUpdateWidget(covariant CachedCircleAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatPictureUrl != widget.chatPictureUrl ||
        oldWidget.chatPictureVersion != widget.chatPictureVersion) {
      // Profile URL changed -> re-construct and re-check cache
      // Use setState to trigger immediate rebuild (important for deletion case)
      setState(() {
        _imagePath = null;
      });
      _constructFullUrl();
      _attemptLoadCachedImage();
    }
  }

  /// Pre-construct full URL once (like profile page provider does)
  void _constructFullUrl() {
    final url = widget.chatPictureUrl;
    if (url == null || url.isEmpty) {
      _baseUrl = null;
      _fullUrl = null;
      return;
    }

    final base = url.startsWith('http') ? url : '${ApiUrls.mediaBaseUrl}$url';
    _baseUrl = base;
    final v = widget.chatPictureVersion;
    if (v == null || v.trim().isEmpty) {
      _fullUrl = base;
      return;
    }

    try {
      final uri = Uri.parse(base);
      final params = Map<String, String>.from(uri.queryParameters);
      params['v'] = v;
      _fullUrl = uri.replace(queryParameters: params).toString();
    } catch (_) {
      final sep = base.contains('?') ? '&' : '?';
      _fullUrl = '$base${sep}v=$v';
    }
  }

  /// WHATSAPP-STYLE: Optimized image loading
  /// 1. Check cache first (instant, no network)
  /// 2. Use cached connectivity state (no async delay)
  /// 3. Background refresh for stale images
  Future<void> _attemptLoadCachedImage() async {
    if (_fullUrl == null) return;

    try {
      final urlsToTry = <String>[_fullUrl!];
      if (_baseUrl != null && _baseUrl!.isNotEmpty && _baseUrl != _fullUrl) {
        urlsToTry.add(_baseUrl!);
      }

      for (final candidateUrl in urlsToTry) {
        final cached = await AuthenticatedImageCacheManager.instance
            .getFileFromCache(candidateUrl);
        if (cached?.file != null) {
          if (mounted) {
            setState(() {
              _imagePath = cached!.file.path;
            });
          }
          // Background refresh for stale images (non-blocking)
          try {
            final validTill = cached!.validTill;
            final isStale = DateTime.now().isAfter(validTill);
            if (isStale && ConnectivityCache.instance.isOnline) {
              AuthenticatedImageCacheManager.instance
                  .getSingleFile(_fullUrl!)
                  .then((_) {})
                  .catchError((_) {});
              if (kDebugMode) {
                debugPrint(
                  '🖼️ [Avatar] stale -> background refresh: $_fullUrl',
                );
              }
            }
          } catch (_) {}
          return;
        }
      }

      // 2) Not in cache - download only if online (using cached state - instant!)
      if (ConnectivityCache.instance.isOnline) {
        try {
          final file = await AuthenticatedImageCacheManager.instance
              .getSingleFile(_fullUrl!);
          if (mounted) {
            setState(() {
              _imagePath = file.path;
            });
          }
        } catch (_) {}
      }
    } catch (e) {
      // ignore - will show default icon
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocal = _imagePath != null && _imagePath!.isNotEmpty;
    final hasNetwork = _fullUrl != null;

    // No image at all - show placeholder
    if (!hasLocal && !hasNetwork) {
      return _buildFallback();
    }

    // Has local cached file - use Image.file (works offline!)
    if (hasLocal) {
      return ClipOval(
        child: Image.file(
          File(_imagePath!),
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) => _buildFallback(),
        ),
      );
    }

    // Fallback to CachedNetworkImage (will populate cache)
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: _fullUrl!,
        cacheManager: AuthenticatedImageCacheManager.instance,
        width: widget.radius * 2,
        height: widget.radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildFallback(),
        errorWidget: (context, url, error) => _buildFallback(),
        // Once image is downloaded & cached, capture the cached file and set _imagePath
        imageBuilder: (ctx, imageProvider) {
          // Kick off a microtask to fetch the cached file and set local path
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              final cached = await AuthenticatedImageCacheManager.instance
                  .getFileFromCache(_fullUrl!);
              if (cached?.file != null) {
                if (mounted) {
                  setState(() {
                    _imagePath = cached!.file.path;
                  });
                }
              } else {
                // Try to download (this will populate cache manager)
                final file = await AuthenticatedImageCacheManager.instance
                    .getSingleFile(_fullUrl!);
                if (mounted) {
                  setState(() {
                    _imagePath = file.path;
                  });
                }
              }
            } catch (_) {}
          });

          return Image(image: imageProvider, fit: BoxFit.cover);
        },
      ),
    );
  }

  /// Build fallback widget: initials with colored background, or default icon
  Widget _buildFallback() {
    final name = widget.contactName;
    if (name != null && name.trim().isNotEmpty) {
      final initials = CachedCircleAvatar.getInitials(name);
      final color = CachedCircleAvatar.getColorForName(name);
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: color,
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.radius * 0.82,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor,
      child: Icon(
        Icons.person,
        size: widget.radius * 1.2,
        color: widget.iconColor,
      ),
    );
  }
}
