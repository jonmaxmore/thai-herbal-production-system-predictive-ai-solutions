class CertificationApplication {
  final int id;
  final int farmerId;
  final DateTime createdAt;
  CertificationStatus status;
  List<String> documents;
  List<String> images;
  String? rejectionReason;
  DateTime? remoteAssessmentDate;
  String? remoteMeetingLink;
  List<String>? additionalImages;
  int? predictiveTeamMemberId;
  int? dpmOfficerId;
  int? labId;
  String? labResultUrl;
  String? certificateUrl;
  String? qrCode;

  CertificationApplication({
    required this.id,
    required this.farmerId,
    required this.createdAt,
    required this.status,
    required this.documents,
    required this.images,
    this.rejectionReason,
    this.remoteAssessmentDate,
    this.remoteMeetingLink,
    this.additionalImages,
    this.predictiveTeamMemberId,
    this.dpmOfficerId,
    this.labId,
    this.labResultUrl,
    this.certificateUrl,
    this.qrCode,
  });

  // JSON serialization/deserialization methods
  factory CertificationApplication.fromMap(Map<String, dynamic> map) {
    return CertificationApplication(
      id: map['id'],
      farmerId: map['farmer_id'],
      createdAt: DateTime.parse(map['created_at']),
      status: CertificationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CertificationStatus.draft,
      ),
      documents: List<String>.from(json.decode(map['documents'])),
      images: List<String>.from(json.decode(map['images'])),
      rejectionReason: map['rejection_reason'],
      remoteAssessmentDate: map['remote_assessment_date'] != null
          ? DateTime.parse(map['remote_assessment_date'])
          : null,
      remoteMeetingLink: map['remote_meeting_link'],
      additionalImages: map['additional_images'] != null
          ? List<String>.from(json.decode(map['additional_images']))
          : null,
      predictiveTeamMemberId: map['predictive_team_member_id'],
      dpmOfficerId: map['dpm_officer_id'],
      labId: map['lab_id'],
      labResultUrl: map['lab_result_url'],
      certificateUrl: map['certificate_url'],
      qrCode: map['qr_code'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'farmer_id': farmerId,
      'created_at': createdAt.toIso8601String(),
      'status': status.name,
      'documents': json.encode(documents),
      'images': json.encode(images),
      'rejection_reason': rejectionReason,
      'remote_assessment_date': remoteAssessmentDate?.toIso8601String(),
      'remote_meeting_link': remoteMeetingLink,
      'additional_images': json.encode(additionalImages),
      'predictive_team_member_id': predictiveTeamMemberId,
      'dpm_officer_id': dpmOfficerId,
      'lab_id': labId,
      'lab_result_url': labResultUrl,
      'certificate_url': certificateUrl,
      'qr_code': qrCode,
    };
  }
}

enum CertificationStatus {
  draft,
  submitted,
  initialAiApproved,
  initialAiRejected,
  remoteAssessmentScheduled,
  remoteAssessmentCompleted,
  remoteAiApproved,
  remoteAiRejected,
  fieldInspectionScheduled,
  fieldInspectionCompleted,
  fieldInspectionApproved,
  fieldInspectionRejected,
  labSampleRequested,
  labSampleReceived,
  labResultsUploaded,
  labResultsApproved,
  labResultsRejected,
  certificateIssued,
  rejected,
}
