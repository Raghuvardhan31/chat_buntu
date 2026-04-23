/// Message reaction user model
class MessageReactionUser {
  final String id;
  final String firstName;
  final String lastName;
  final String? chatPicture;

  MessageReactionUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.chatPicture,
  });

  factory MessageReactionUser.fromJson(Map<String, dynamic> json) {
    return MessageReactionUser(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      chatPicture:
          json['chat_picture']?.toString() ?? json['chatPicture']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'chat_picture': chatPicture,
    };
  }

  String get fullName => '$firstName $lastName';
}
