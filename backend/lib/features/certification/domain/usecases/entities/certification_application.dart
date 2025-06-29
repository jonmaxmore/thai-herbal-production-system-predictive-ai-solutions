enum CertificationStatus {
  draft,
  submitted,
  aiReviewing,
  remoteMeetingScheduled,
  additionalImagesRequested,
  inspectionScheduled,
  inspectionCompleted,
  labResultsPending,
  certificateIssued,
  rejected,
  unknown,
}

class CertificationApplication {
  final String id;
  final String farmerId;
  final String farmerName;
  CertificationStatus status;
  final List<String> herbIds;
  List<String> images;
  DateTime? remoteMeetingDate;
  DateTime? inspectionDate;
  LabResult? labResults;
  String? certificateUrl;
  String? qrCode;

  CertificationApplication({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.status,
    required this.herbIds,
    required this.images,
  });

  factory CertificationApplication.fromJson(Map<String, dynamic> json) {
    return CertificationApplication(
      id: json['id'],
      farmerId: json['farmerId'],
      farmerName: json['farmerName'],
      status: CertificationStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => CertificationStatus.draft,
      ),
      herbIds: List<String>.from(json['herbIds']),
      images: List<String>.from(json['images']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'farmerId': farmerId,
    'farmerName': farmerName,
    'status': status.toString(),
    'herbIds': herbIds,
    'images': images,
  };
}

class LabResult {
  final String testId;
  final DateTime testDate;
  final Map<String, dynamic> parameters;
  final bool passed;

  LabResult({
    required this.testId,
    required this.testDate,
    required this.parameters,
    required this.passed,
  });

  factory LabResult.fromJson(Map<String, dynamic> json) {
    return LabResult(
      testId: json['testId'],
      testDate: DateTime.parse(json['testDate']),
      parameters: Map<String, dynamic>.from(json['parameters']),
      passed: json['passed'],
    );
  }

  Map<String, dynamic> toJson() => {
    'testId': testId,
    'testDate': testDate.toIso8601String(),
    'parameters': parameters,
    'passed': passed,
  };
}
