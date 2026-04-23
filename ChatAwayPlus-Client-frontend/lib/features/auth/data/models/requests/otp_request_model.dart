class OtpRequestModel {
  final String mobileNo;

  OtpRequestModel({
    required this.mobileNo,
  });

  Map<String, dynamic> toJson() {
    return {
      'mobileNo': mobileNo,
    };
  }

  factory OtpRequestModel.fromJson(Map<String, dynamic> json) {
    return OtpRequestModel(
      mobileNo: json['mobileNo'] ?? '',
    );
  }
}
