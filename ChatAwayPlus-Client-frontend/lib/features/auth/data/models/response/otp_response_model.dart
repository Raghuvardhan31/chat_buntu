class OtpVerifyModel {
  final String mobileNo;
  final String otp;

  OtpVerifyModel({
    required this.mobileNo,
    required this.otp,
  });

  Map<String, dynamic> toJson() {
    return {
      'mobileNo': mobileNo,
      'otp': otp,
    };
  }

  factory OtpVerifyModel.fromJson(Map<String, dynamic> json) {
    return OtpVerifyModel(
      mobileNo: json['mobileNo'] ?? '',
      otp: json['otp'] ?? '',
    );
  }
}
