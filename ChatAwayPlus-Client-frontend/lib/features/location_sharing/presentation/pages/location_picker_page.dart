import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/features/location_sharing/data/models/location_model.dart';

/// Full-screen location picker page
/// Shows a real Google Map with current GPS location and "Send Your Location" button
/// Uses geolocator for GPS and geocoding for address resolution
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  GoogleMapController? _mapController;
  bool _isLoadingLocation = true;
  bool _isSending = false;
  String? _errorMessage;

  // Current location data
  double _latitude = 17.385044; // Default fallback (Hyderabad)
  double _longitude = 78.486671;
  String _address = 'Fetching address...';
  String _placeName = 'Current Location';

  // Map camera position
  late CameraPosition _initialCameraPosition;

  @override
  void initState() {
    super.initState();
    _initialCameraPosition = CameraPosition(
      target: LatLng(_latitude, _longitude),
      zoom: 16,
    );
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        // Prompt user to enable GPS
        final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text(
              'Please enable location services (GPS) to share your location.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (shouldOpen == true) {
          await Geolocator.openLocationSettings();
          // After returning from settings, re-check
          if (!mounted) return;
          await Future.delayed(const Duration(milliseconds: 500));
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            if (!mounted) return;
            setState(() {
              _errorMessage = 'Location services are still disabled.';
              _isLoadingLocation = false;
            });
            return;
          }
        } else {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Location services are required to share location.';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Location permission denied.';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Location permission permanently denied. Please enable in Settings.';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isLoadingLocation = false;
      });

      // Move map camera to current location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_latitude, _longitude), 16),
      );

      // Reverse geocode to get address
      _resolveAddress(_latitude, _longitude);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [LocationPicker] Error fetching location: $e');
      }
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _errorMessage = 'Could not get your location. Using default.';
      });
    }
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (!mounted) return;
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = <String>[
          if (place.street != null && place.street!.isNotEmpty) place.street!,
          if (place.subLocality != null && place.subLocality!.isNotEmpty)
            place.subLocality!,
          if (place.locality != null && place.locality!.isNotEmpty)
            place.locality!,
          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty)
            place.administrativeArea!,
          if (place.country != null && place.country!.isNotEmpty)
            place.country!,
        ];
        setState(() {
          _placeName = place.subLocality?.isNotEmpty == true
              ? place.subLocality!
              : place.locality ?? 'Current Location';
          _address = parts.join(', ');
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [LocationPicker] Geocoding error: $e');
      }
      if (!mounted) return;
      setState(() {
        _address =
            '${_latitude.toStringAsFixed(6)}, ${_longitude.toStringAsFixed(6)}';
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (!_isLoadingLocation) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_latitude, _longitude), 16),
      );
    }
  }

  void _onCameraIdle() {
    // When user stops dragging the map, resolve the center address
    _mapController?.getVisibleRegion().then((bounds) {
      final centerLat =
          (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
      final centerLng =
          (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
      if ((centerLat - _latitude).abs() > 0.0001 ||
          (centerLng - _longitude).abs() > 0.0001) {
        setState(() {
          _latitude = centerLat;
          _longitude = centerLng;
        });
        _resolveAddress(centerLat, centerLng);
      }
    });
  }

  void _recenterToCurrentLocation() {
    setState(() => _isLoadingLocation = true);
    _fetchCurrentLocation();
  }

  void _sendLocation() {
    setState(() => _isSending = true);

    final location = LocationModel(
      latitude: _latitude,
      longitude: _longitude,
      address: _address,
      placeName: _placeName,
      timestamp: DateTime.now(),
    );

    // Pop and return the location data
    Navigator.of(context).pop(location);
  }

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

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          appBar: _buildAppBar(responsive, isDark),
          body: Stack(
            children: [
              // Google Map
              _buildGoogleMap(isDark),
              // Center pin (always visible, overlays the map center)
              _buildCenterPin(responsive),
              // Bottom card with location info + send button
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomCard(responsive, isDark),
              ),
              // Loading overlay
              if (_isLoadingLocation) _buildLoadingOverlay(responsive),
              // Error banner
              if (_errorMessage != null && !_isLoadingLocation)
                _buildErrorBanner(responsive),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ResponsiveSize responsive, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Share Location',
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          fontSize: responsive.size(18),
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            Icons.my_location_rounded,
            color: AppColors.primary,
            size: responsive.size(22),
          ),
          onPressed: _recenterToCurrentLocation,
        ),
      ],
    );
  }

  Widget _buildGoogleMap(bool isDark) {
    return GoogleMap(
      initialCameraPosition: _initialCameraPosition,
      onMapCreated: _onMapCreated,
      onCameraIdle: _onCameraIdle,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      mapType: MapType.normal,
    );
  }

  Widget _buildCenterPin(ResponsiveSize responsive) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: responsive.size(48)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: responsive.size(44),
              height: responsive.size(44),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                    blurRadius: responsive.size(12),
                    offset: Offset(0, responsive.size(4)),
                  ),
                ],
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: responsive.size(24),
              ),
            ),
            CustomPaint(
              size: Size(responsive.size(12), responsive.size(12)),
              painter: _PinTailPainter(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCard(ResponsiveSize responsive, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(responsive.size(24)),
          topRight: Radius.circular(responsive.size(24)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: responsive.size(20),
            offset: Offset(0, -responsive.size(4)),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            responsive.spacing(20),
            responsive.spacing(20),
            responsive.spacing(20),
            responsive.spacing(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: responsive.size(40),
                height: responsive.size(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(responsive.size(2)),
                ),
              ),
              SizedBox(height: responsive.spacing(20)),
              // Send current location button
              _buildSendLocationButton(responsive, isDark),
              SizedBox(height: responsive.spacing(16)),
              // Location info row
              _buildLocationInfoRow(responsive, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendLocationButton(ResponsiveSize responsive, bool isDark) {
    return GestureDetector(
      onTap: _isLoadingLocation || _isSending ? null : _sendLocation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: responsive.spacing(14)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(responsive.size(14)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: responsive.size(12),
              offset: Offset(0, responsive.size(4)),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.near_me_rounded,
              color: Colors.white,
              size: responsive.size(20),
            ),
            SizedBox(width: responsive.spacing(10)),
            Text(
              _isSending ? 'Sending...' : 'Send Your Current Location',
              style: TextStyle(
                color: Colors.white,
                fontSize: responsive.size(15),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfoRow(ResponsiveSize responsive, bool isDark) {
    return Row(
      children: [
        Container(
          width: responsive.size(42),
          height: responsive.size(42),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(responsive.size(12)),
          ),
          child: Icon(
            Icons.add_location_alt_rounded,
            color: AppColors.primary,
            size: responsive.size(20),
          ),
        ),
        SizedBox(width: responsive.spacing(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isLoadingLocation ? 'Fetching location...' : _placeName,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                  fontSize: responsive.size(15),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: responsive.spacing(2)),
              Text(
                _isLoadingLocation ? 'Please wait...' : _address,
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  fontSize: responsive.size(12),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (!_isLoadingLocation)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacing(8),
              vertical: responsive.spacing(4),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(responsive.size(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: const Color(0xFF22C55E),
                  size: responsive.size(14),
                ),
                SizedBox(width: responsive.spacing(4)),
                Text(
                  'GPS',
                  style: TextStyle(
                    color: const Color(0xFF22C55E),
                    fontSize: responsive.size(11),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingOverlay(ResponsiveSize responsive) {
    return Container(
      color: Colors.black.withValues(alpha: 0.15),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(responsive.spacing(24)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(responsive.size(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: responsive.size(20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: responsive.size(40),
                height: responsive.size(40),
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              SizedBox(height: responsive.spacing(16)),
              Text(
                'Getting your location...',
                style: TextStyle(
                  color: const Color(0xFF374151),
                  fontSize: responsive.size(14),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(ResponsiveSize responsive) {
    return Positioned(
      top: responsive.spacing(12),
      left: responsive.spacing(16),
      right: responsive.spacing(16),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(responsive.size(12)),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(16),
            vertical: responsive.spacing(12),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(responsive.size(12)),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: const Color(0xFFEF4444),
                size: responsive.size(20),
              ),
              SizedBox(width: responsive.spacing(10)),
              Expanded(
                child: Text(
                  _errorMessage ?? '',
                  style: TextStyle(
                    color: const Color(0xFF991B1B),
                    fontSize: responsive.size(13),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _errorMessage = null),
                child: Icon(
                  Icons.close_rounded,
                  color: const Color(0xFF991B1B),
                  size: responsive.size(18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the pin tail triangle
class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
