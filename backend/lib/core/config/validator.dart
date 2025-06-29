import 'dart:io';
import 'package:mime/mime.dart';
import 'constants.dart';

class ConfigValidator {
  static void validateConfig(AppConfig config) {
    final errors = <String>[];
    
    if (config.jwtSecret.isEmpty || config.jwtSecret == 'default_herbal_secret') {
      errors.add('JWT_SECRET must be set and secure');
    }
    
    if (config.mongodbUri.isEmpty || !config.mongodbUri.startsWith('mongodb://')) {
      errors.add('MONGODB_URI must be a valid MongoDB connection string');
    }
    
    if (config.dbName.isEmpty) {
      errors.add('DB_NAME must be set');
    }
    
    if (config.aiModelPath.isEmpty) {
      errors.add('AI_MODEL_PATH must be set');
    } else {
      final dir = Directory(config.aiModelPath);
      if (!dir.existsSync()) {
        errors.add('AI_MODEL_PATH directory does not exist: ${config.aiModelPath}');
      }
    }
    
    if (config.storagePath.isEmpty) {
      errors.add('STORAGE_PATH must be set');
    }
    
    if (errors.isNotEmpty) {
      throw Exception('Configuration validation failed:\n${errors.join('\n')}');
    }
  }

  static bool isValidImage(File file) {
    final sizeMB = file.lengthSync() / (1024 * 1024);
    if (sizeMB > ApiConstants.maxImageSizeMB) {
      return false;
    }
    
    final mimeType = lookupMimeType(file.path);
    return mimeType != null && 
           ApiConstants.allowedImageTypes.contains(mimeType);
  }

  static bool isValidVideo(File file) {
    final sizeMB = file.lengthSync() / (1024 * 1024);
    if (sizeMB > ApiConstants.maxVideoSizeMB) {
      return false;
    }
    
    final mimeType = lookupMimeType(file.path);
    return mimeType != null && 
           ApiConstants.allowedVideoTypes.contains(mimeType);
  }

  static bool hasPermission(String role, String permission) {
    final perms = ApiConstants.rolePermissions[role] ?? '';
    return perms.contains('all') || perms.contains(permission);
  }
}
