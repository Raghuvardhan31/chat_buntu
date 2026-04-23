import 'package:flutter/foundation.dart';

/// Model representing a shared location message
@immutable
class LocationModel {
  final double latitude;
  final double longitude;
  final String? address;
  final String? placeName;
  final DateTime timestamp;

  const LocationModel({
    required this.latitude,
    required this.longitude,
    this.address,
    this.placeName,
    required this.timestamp,
  });

  /// Formatted coordinates string
  String get formattedCoordinates =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  /// Display label — place name or address or coordinates
  String get displayLabel =>
      placeName ?? address ?? formattedCoordinates;

  /// Short display for chat bubble subtitle
  String get shortDisplay =>
      placeName ?? address?.split(',').first ?? formattedCoordinates;

  /// Google Maps static map URL for thumbnail preview
  /// Requires a valid API key to render — returns placeholder URL for now
  String staticMapUrl({
    int width = 400,
    int height = 200,
    int zoom = 15,
    String? apiKey,
  }) {
    if (apiKey == null || apiKey.isEmpty) {
      // Return empty — UI will show a placeholder instead
      return '';
    }
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$latitude,$longitude'
        '&zoom=$zoom'
        '&size=${width}x$height'
        '&maptype=roadmap'
        '&markers=color:red%7C$latitude,$longitude'
        '&key=$apiKey';
  }

  /// Google Maps URL for opening in external maps app
  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'placeName': placeName,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      placeName: json['placeName'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  LocationModel copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? placeName,
    DateTime? timestamp,
  }) {
    return LocationModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      placeName: placeName ?? this.placeName,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
