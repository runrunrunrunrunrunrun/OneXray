class NetBirdStartOAuthRequest {
  final String? managementUrl;
  final String? existingPrivateKey;
  final int? timeoutSeconds;

  const NetBirdStartOAuthRequest({
    this.managementUrl,
    this.existingPrivateKey,
    this.timeoutSeconds,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (managementUrl != null) 'managementUrl': managementUrl,
    if (existingPrivateKey != null) 'existingPrivateKey': existingPrivateKey,
    if (timeoutSeconds != null) 'timeoutSeconds': timeoutSeconds,
  };
}

class NetBirdStartOAuthResponse {
  final String sessionId;
  final String authUrl;
  final String? userCode;
  final String flowType;
  final int? expiresIn;

  const NetBirdStartOAuthResponse({
    required this.sessionId,
    required this.authUrl,
    this.userCode,
    required this.flowType,
    this.expiresIn,
  });

  factory NetBirdStartOAuthResponse.fromJson(Map<String, dynamic> json) {
    return NetBirdStartOAuthResponse(
      sessionId: json['sessionId'] as String? ?? '',
      authUrl: json['authUrl'] as String? ?? '',
      userCode: json['userCode'] as String?,
      flowType: json['flowType'] as String? ?? '',
      expiresIn: (json['expiresIn'] as num?)?.toInt(),
    );
  }
}

class NetBirdCompleteOAuthRequest {
  final String sessionId;
  final String? deviceName;
  final int? timeoutSeconds;

  const NetBirdCompleteOAuthRequest({
    required this.sessionId,
    this.deviceName,
    this.timeoutSeconds,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sessionId': sessionId,
    if (deviceName != null) 'deviceName': deviceName,
    if (timeoutSeconds != null) 'timeoutSeconds': timeoutSeconds,
  };
}

class NetBirdCompleteOAuthResponse {
  final String privateKey;
  final String publicKey;
  final String? peerIp;
  final String? fqdn;
  final String? managementUrl;

  const NetBirdCompleteOAuthResponse({
    required this.privateKey,
    required this.publicKey,
    this.peerIp,
    this.fqdn,
    this.managementUrl,
  });

  factory NetBirdCompleteOAuthResponse.fromJson(Map<String, dynamic> json) {
    return NetBirdCompleteOAuthResponse(
      privateKey: json['privateKey'] as String? ?? '',
      publicKey: json['publicKey'] as String? ?? '',
      peerIp: json['peerIp'] as String?,
      fqdn: json['fqdn'] as String?,
      managementUrl: json['managementUrl'] as String?,
    );
  }
}

class NetBirdCancelOAuthRequest {
  final String sessionId;

  const NetBirdCancelOAuthRequest({required this.sessionId});

  Map<String, dynamic> toJson() => <String, dynamic>{'sessionId': sessionId};
}
