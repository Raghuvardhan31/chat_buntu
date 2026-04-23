import 'package:flutter/material.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/location_sharing/data/config/maps_config.dart';
import 'package:chataway_plus/features/location_sharing/data/models/location_model.dart';

/// Chat bubble widget for displaying a shared location message
/// Shows a static Google Maps thumbnail with location name and address
/// Tapping opens the location in Google Maps
class LocationMessageBubble extends StatelessWidget {
  final LocationModel location;
  final bool isMe;
  final VoidCallback? onTap;

  const LocationMessageBubble({
    super.key,
    required this.location,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResponsiveLayoutBuilder(
      builder: (context, constraints, breakpoint) {
        final responsive = ResponsiveSize(
          context: context,
          constraints: constraints,
          breakpoint: breakpoint,
        );

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: responsive.size(250),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isMe
                  ? (isDark ? const Color(0xFF1E3A5F) : AppColors.senderBubble)
                  : (isDark
                        ? const Color(0xFF1E293B)
                        : AppColors.receiverBubble),
              borderRadius: BorderRadius.circular(responsive.size(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: responsive.size(6),
                  offset: Offset(0, responsive.size(2)),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Map preview area
                _buildMapPreview(responsive, isDark),
                // Location info
                _buildLocationInfo(responsive, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapPreview(ResponsiveSize responsive, bool isDark) {
    final staticUrl = location.staticMapUrl(
      width: 500,
      height: 260,
      zoom: 15,
      apiKey: MapsConfig.apiKey,
    );

    return Container(
      width: double.infinity,
      height: responsive.size(130),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2332) : const Color(0xFFF1F5F9),
      ),
      child: Stack(
        children: [
          // Static map image from Google Maps
          if (staticUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                staticUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackMapPreview(responsive, isDark);
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
            _buildFallbackMapPreview(responsive, isDark),
          // "View on Maps" overlay
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

  Widget _buildFallbackMapPreview(ResponsiveSize responsive, bool isDark) {
    // Fallback pin icon when static map image is unavailable
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

  Widget _buildLocationInfo(ResponsiveSize responsive, bool isDark) {
    return Padding(
      padding: EdgeInsets.all(responsive.spacing(10)),
      child: Row(
        children: [
          Icon(
            Icons.location_on_rounded,
            color: AppColors.primary,
            size: responsive.size(18),
          ),
          SizedBox(width: responsive.spacing(6)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.shortDisplay,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    fontSize: responsive.size(13),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (location.address != null &&
                    location.address != location.placeName)
                  Text(
                    location.address!,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                      fontSize: responsive.size(11),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
