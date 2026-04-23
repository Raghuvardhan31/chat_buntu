import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/chat/models/chat_message_model.dart';
import 'package:chataway_plus/features/chat/presentation/widgets/chat_ui/message_delivery_status_icon.dart';
import 'package:chataway_plus/features/chat/utils/chat_helper.dart';
import 'package:chataway_plus/features/location_sharing/data/config/maps_config.dart';

/// Location sharing message bubble
/// Shows a static Google Maps thumbnail with location name, address,
/// timestamp, and delivery status. Tapping opens Google Maps.
class LocationMessageBubble extends StatelessWidget {
  const LocationMessageBubble({
    super.key,
    required this.message,
    required this.isSender,
    this.bubbleColor,
    this.showTail = true,
  });

  final ChatMessageModel message;
  final bool isSender;
  final Color? bubbleColor;
  final bool showTail;

  BorderRadius _getBubbleRadius(ResponsiveSize responsive) {
    final radius = responsive.size(16);
    final smallRadius = responsive.size(4);

    if (isSender) {
      return BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(showTail ? smallRadius : radius),
      );
    } else {
      return BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(showTail ? smallRadius : radius),
        bottomRight: Radius.circular(radius),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final payload = _LocationPayload.fromMessage(message.message);

        final defaultBubbleColor = isSender
            ? (isDark ? const Color(0xFF1E3A5F) : AppColors.senderBubble)
            : (isDark ? const Color(0xFF2D2D2D) : AppColors.receiverBubble);

        final textColor = isDark ? Colors.white : Colors.black87;
        final secondaryTextColor = isDark
            ? Colors.white70
            : AppColors.colorGrey;

        return GestureDetector(
          onTap: () => _openInGoogleMaps(payload),
          child: Container(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: bubbleColor ?? defaultBubbleColor,
              borderRadius: _getBubbleRadius(responsive),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Map thumbnail
                _buildMapThumbnail(responsive, isDark, payload),
                // Location info + timestamp
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.spacing(12),
                    vertical: responsive.spacing(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: responsive.size(18),
                            color: AppColors.primary,
                          ),
                          SizedBox(width: responsive.spacing(6)),
                          Flexible(
                            child: Text(
                              payload.placeName ?? 'Shared Location',
                              style: TextStyle(
                                color: textColor,
                                fontSize: responsive.size(14),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (payload.address != null &&
                          payload.address != payload.placeName) ...[
                        SizedBox(height: responsive.spacing(2)),
                        Padding(
                          padding: EdgeInsets.only(
                            left: responsive.spacing(22),
                          ),
                          child: Text(
                            payload.address!,
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: responsive.size(12),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      SizedBox(height: responsive.spacing(4)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ChatHelper.formatMessageTime(message.createdAt),
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: responsive.size(11),
                              ),
                            ),
                            if (isSender) ...[
                              SizedBox(width: responsive.spacing(4)),
                              MessageDeliveryStatusIcon(
                                status: message.messageStatus,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapThumbnail(
    ResponsiveSize responsive,
    bool isDark,
    _LocationPayload payload,
  ) {
    final staticUrl = _buildStaticMapUrl(payload);

    return Container(
      width: double.infinity,
      height: responsive.size(160),
      color: isDark ? const Color(0xFF1A2332) : const Color(0xFFF1F5F9),
      child: Stack(
        children: [
          if (staticUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                staticUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackThumbnail(responsive, isDark);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: responsive.size(24),
                      height: responsive.size(24),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            _buildFallbackThumbnail(responsive, isDark),
          // "View on Maps" badge
          Positioned(
            right: responsive.spacing(8),
            top: responsive.spacing(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacing(8),
                vertical: responsive.spacing(4),
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(responsive.size(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_new_rounded,
                    color: Colors.white,
                    size: responsive.size(12),
                  ),
                  SizedBox(width: responsive.spacing(4)),
                  Text(
                    'Maps',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsive.size(10),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackThumbnail(ResponsiveSize responsive, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: responsive.size(32),
            height: responsive.size(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  blurRadius: responsive.size(8),
                  offset: Offset(0, responsive.size(2)),
                ),
              ],
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: responsive.size(18),
            ),
          ),
          Container(
            width: responsive.size(6),
            height: responsive.size(3),
            margin: EdgeInsets.only(top: responsive.spacing(2)),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(responsive.size(3)),
            ),
          ),
        ],
      ),
    );
  }

  String _buildStaticMapUrl(_LocationPayload payload) {
    if (MapsConfig.apiKey.isEmpty) return '';
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=${payload.latitude},${payload.longitude}'
        '&zoom=15'
        '&size=600x320'
        '&scale=2'
        '&maptype=roadmap'
        '&markers=color:red%7C${payload.latitude},${payload.longitude}'
        '&key=${MapsConfig.apiKey}';
  }

  Future<void> _openInGoogleMaps(_LocationPayload payload) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${payload.latitude},${payload.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

/// Parses location data from the message string (JSON format)
class _LocationPayload {
  const _LocationPayload({
    required this.latitude,
    required this.longitude,
    this.address,
    this.placeName,
  });

  final double latitude;
  final double longitude;
  final String? address;
  final String? placeName;

  static _LocationPayload fromMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const _LocationPayload(latitude: 0, longitude: 0);
    }

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    if (data != null) {
      return _LocationPayload(
        latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
        address: data['address'] as String?,
        placeName: data['placeName'] as String?,
      );
    }

    // Fallback: try parsing as "lat,lng" format
    final parts = trimmed.split(',');
    if (parts.length >= 2) {
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        return _LocationPayload(latitude: lat, longitude: lng);
      }
    }

    return const _LocationPayload(latitude: 0, longitude: 0);
  }
}
