class ApiConstants {
  static const String apiVersion = 'v1';
  static const String basePath = '/api/$apiVersion';
  
  static const int maxImageSizeMB = 10;
  static const int maxVideoSizeMB = 100;
  static const int defaultPageSize = 20;
  
  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
  ];
  
  static const List<String> allowedVideoTypes = [
    'video/mp4',
    'video/quicktime',
  ];
  
  static const Map<String, String> rolePermissions = {
    'farmer': 'submit:certification,read:own',
    'inspector': 'schedule:inspection,complete:inspection',
    'lab_technician': 'submit:lab_results',
    'admin': 'all',
  };
}

class DbConstants {
  static const String applicationsCollection = 'herbal_applications';
  static const String usersCollection = 'herbal_users';
  static const String certificatesCollection = 'herbal_certificates';
  static const String aiModelsCollection = 'ai_models';
  
  static const Map<String, dynamic> applicationIndexes = {
    'farmer_id': 1,
    'status': 1,
    'created_at': -1,
  };
}

class PathConstants {
  static const String imageUploads = 'uploads/images';
  static const String videoUploads = 'uploads/videos';
  static const String certificates = 'certificates';
  static const String tempDir = 'temp';
  
  static String modelPath(String modelName) {
    return 'assets/models/$modelName';
  }
}

class ErrorMessages {
  static const String invalidCredentials = 'Invalid credentials';
  static const String unauthorized = 'Unauthorized access';
  static const String forbidden = 'Forbidden resource';
  static const String notFound = 'Resource not found';
  static const String serverError = 'Internal server error';
  static const String invalidImage = 'Invalid image format or size';
  static const String dbConnection = 'Database connection failed';
  static const String aiProcessing = 'AI processing error';
}
