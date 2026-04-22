class LiveKitToken {
  final String token;
  final String roomName;
  final String wsUrl;

  const LiveKitToken({
    required this.token,
    required this.roomName,
    required this.wsUrl,
  });

  factory LiveKitToken.fromMap(Map<String, dynamic> m) => LiveKitToken(
    token: m['token'] as String,
    roomName: m['roomName'] as String,
    wsUrl: m['wsUrl'] as String,
  );
}
