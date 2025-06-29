extension CertificationApplicationCopyWith on CertificationApplication {
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
    )
      ..remoteMeetingDate = remoteMeetingDate ?? this.remoteMeetingDate
      ..inspectionDate = inspectionDate ?? this.inspectionDate
      ..labResults = labResults ?? this.labResults
      ..certificateUrl = certificateUrl ?? this.certificateUrl
      ..qrCode = qrCode ?? this.qrCode;
  }
}
