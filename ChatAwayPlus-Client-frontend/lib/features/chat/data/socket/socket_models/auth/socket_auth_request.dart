/// Socket authentication request model
class SocketAuthRequest {
  final String currentUserId;
  final bool loadHistory;
  final String? token;

  SocketAuthRequest({
    required this.currentUserId,
    this.loadHistory = false,
    this.token,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': currentUserId,
      'loadHistory': loadHistory,
      'token': token,
    };
  }
}
