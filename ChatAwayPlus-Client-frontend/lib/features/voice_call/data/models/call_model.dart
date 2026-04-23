import 'package:flutter/foundation.dart';

/// Represents the type of call
enum CallType { voice, video }

/// Represents the status of a call
enum CallStatus {
  /// Call is ringing (incoming or outgoing)
  ringing,

  /// Call is active/ongoing
  active,

  /// Call ended normally
  ended,

  /// Call was missed (not answered)
  missed,

  /// Call was rejected by the receiver
  rejected,

  /// Call failed due to network or other issues
  failed,
}

/// Represents the direction of a call
enum CallDirection { incoming, outgoing }

/// Model representing a single call record
@immutable
class CallModel {
  final String id;
  final String contactId;
  final String contactName;
  final String? contactProfilePic;
  final CallType callType;
  final CallDirection direction;
  final CallStatus status;
  final DateTime timestamp;
  final int? durationSeconds;

  const CallModel({
    required this.id,
    required this.contactId,
    required this.contactName,
    this.contactProfilePic,
    required this.callType,
    required this.direction,
    required this.status,
    required this.timestamp,
    this.durationSeconds,
  });

  /// Whether this call was missed
  bool get isMissed => status == CallStatus.missed;

  /// Whether this call was outgoing
  bool get isOutgoing => direction == CallDirection.outgoing;

  /// Whether this call was incoming
  bool get isIncoming => direction == CallDirection.incoming;

  /// Formatted duration string (e.g., "2:34")
  String get formattedDuration {
    if (durationSeconds == null || durationSeconds == 0) return '';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Create a copy with modified fields
  CallModel copyWith({
    String? id,
    String? contactId,
    String? contactName,
    String? contactProfilePic,
    CallType? callType,
    CallDirection? direction,
    CallStatus? status,
    DateTime? timestamp,
    int? durationSeconds,
  }) {
    return CallModel(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      contactProfilePic: contactProfilePic ?? this.contactProfilePic,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactId': contactId,
      'contactName': contactName,
      'contactProfilePic': contactProfilePic,
      'callType': callType.name,
      'direction': direction.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'durationSeconds': durationSeconds,
    };
  }

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'] as String,
      contactId: json['contactId'] as String,
      contactName: json['contactName'] as String,
      contactProfilePic: json['contactProfilePic'] as String?,
      callType: CallType.values.firstWhere(
        (e) => e.name == json['callType'],
        orElse: () => CallType.voice,
      ),
      direction: CallDirection.values.firstWhere(
        (e) => e.name == json['direction'],
        orElse: () => CallDirection.outgoing,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CallStatus.ended,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      durationSeconds: json['durationSeconds'] as int?,
    );
  }
}

/// Model representing an active/ongoing call state
@immutable
class ActiveCallState {
  final String callId;
  final String contactId;
  final String contactName;
  final String? contactProfilePic;
  final CallType callType;
  final CallDirection direction;
  final CallStatus status;
  final DateTime startTime;
  final bool isMuted;
  final bool isSpeakerOn;

  const ActiveCallState({
    required this.callId,
    required this.contactId,
    required this.contactName,
    this.contactProfilePic,
    required this.callType,
    required this.direction,
    required this.status,
    required this.startTime,
    this.isMuted = false,
    this.isSpeakerOn = false,
  });

  ActiveCallState copyWith({
    String? callId,
    String? contactId,
    String? contactName,
    String? contactProfilePic,
    CallType? callType,
    CallDirection? direction,
    CallStatus? status,
    DateTime? startTime,
    bool? isMuted,
    bool? isSpeakerOn,
  }) {
    return ActiveCallState(
      callId: callId ?? this.callId,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      contactProfilePic: contactProfilePic ?? this.contactProfilePic,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
    );
  }
}
