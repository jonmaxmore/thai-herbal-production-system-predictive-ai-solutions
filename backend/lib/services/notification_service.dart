import 'package:thai_herbal_backend/core/messaging/messaging_service.dart';
import 'package:thai_herbal_backend/models/user.dart';
import 'package:thai_herbal_backend/models/certification.dart';

class NotificationService {
  final MessagingService _messagingService;
  final PostgresRepository _repository;

  NotificationService(this._messagingService, this._repository);

  Future<void> sendRejectionNotification(
    int farmerId,
    String reason,
    int applicationId,
  ) async {
    final farmer = await _getUser(farmerId);
    await _messagingService.sendMessage(
      userId: farmerId,
      title: 'Application Rejected',
      body: 'Your application #$applicationId was rejected: $reason',
      data: {'type': 'rejection', 'application_id': applicationId.toString()},
    );
    
    // Also send via email if available
    if (farmer.email != null) {
      await _sendEmail(
        farmer.email!,
        'GACP Application Rejected',
        'Your application #$applicationId was rejected. Reason: $reason',
      );
    }
  }

  Future<void> sendMeetingScheduledNotification(
    int farmerId,
    DateTime meetingTime,
    String meetingLink,
  ) async {
    final farmer = await _getUser(farmerId);
    await _messagingService.sendMessage(
      userId: farmerId,
      title: 'Remote Meeting Scheduled',
      body: 'Meeting scheduled at ${meetingTime.toLocal()}',
      data: {
        'type': 'meeting',
        'meeting_time': meetingTime.toIso8601String(),
        'meeting_link': meetingLink,
      },
    );
    
    // Also send calendar invite
    await _sendCalendarInvite(farmer.email, meetingTime, meetingLink);
  }

  Future<void> sendLabSampleRequest(int farmerId, int applicationId) async {
    final farmer = await _getUser(farmerId);
    await _messagingService.sendMessage(
      userId: farmerId,
      title: 'Lab Sample Required',
      body: 'Please send samples for application #$applicationId',
      data: {'type': 'lab_request', 'application_id': applicationId.toString()},
    );
    
    if (farmer.email != null) {
      await _sendEmail(
        farmer.email!,
        'Lab Sample Required',
        'Please send herb samples to our lab for application #$applicationId',
      );
    }
  }

  Future<void> sendCertificateIssued(
    int farmerId,
    int applicationId,
    String certificateUrl,
    String qrCode,
  ) async {
    final farmer = await _getUser(farmerId);
    await _messagingService.sendMessage(
      userId: farmerId,
      title: 'Certificate Issued!',
      body: 'Your GACP certificate #$applicationId is ready',
      data: {
        'type': 'certificate',
        'application_id': applicationId.toString(),
        'certificate_url': certificateUrl,
        'qr_code': qrCode,
      },
    );
    
    if (farmer.email != null) {
      await _sendEmailWithAttachment(
        farmer.email!,
        'GACP Certificate Issued',
        'Congratulations! Your certificate is attached.',
        certificateUrl,
      );
    }
  }

  Future<User> _getUser(int id) async {
    final result = await _repository.query(
      'SELECT * FROM users WHERE id = @id',
      substitutionValues: {'id': id},
    );
    return User.fromMap(result.first);
  }

  // Email sending implementations...
}
