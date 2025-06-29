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
    this.remoteMeetingDate,
    this.inspectionDate,
    this.labResults,
    this.certificateUrl,
    this.qrCode,
  });

  CertificationApplication copyWith({
    String? id,
    String? farmerId,
    String? farmerName,
    CertificationStatus? status,
    List<String>? herbIds,
    List<String>? images,
    DateTime? remoteMeetingDate,
    DateTime? inspectionDate,
    LabResult? labResults,
    String? certificateUrl,
    String? qrCode,
  }) {
    return CertificationApplication(
      id: id ?? this.id,
      farmerId: farmerId ?? this.farmerId,
      farmerName: farmerName ?? this.farmerName,
      status: status ?? this.status,
      herbIds: herbIds ?? this.herbIds,
      images: images ?? this.images,
      remoteMeetingDate: remoteMeetingDate ?? this.remoteMeetingDate,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      labResults: labResults ?? this.labResults,
      certificateUrl: certificateUrl ?? this.certificateUrl,
      qrCode: qrCode ?? this.qrCode,
    );
  }
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

  Map<String, dynamic> toJson() => {
    'testId': testId,
    'testDate': testDate.toIso8601String(),
    'parameters': parameters,
    'passed': passed,
  };
}
