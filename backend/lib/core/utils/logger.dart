import 'dart:developer' as developer;
import 'package:logging/logging.dart';
import 'package:backend/core/config/env_config.dart';

abstract class Logger {
  void info(String message, {Map<String, dynamic>? context});
  void warning(String message, {Map<String, dynamic>? context});
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context});
  void debug(String message, {Map<String, dynamic>? context});
}

class ProductionLogger implements Logger {
  final Logger _logger = Logger('ThaiHerbalLogger');
  final EnvConfig _config;

  ProductionLogger() : _config = injector<EnvConfig>() {
    Logger.root.level = _config.isProduction ? Level.INFO : Level.ALL;
    Logger.root.onRecord.listen((record) {
      developer.log(
        record.message,
        time: record.time,
        sequenceNumber: record.sequenceNumber,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }

  @override
  void info(String message, {Map<String, dynamic>? context}) {
    _logger.info('$message ${_formatContext(context)}');
  }

  @override
  void warning(String message, {Map<String, dynamic>? context}) {
    _logger.warning('$message ${_formatContext(context)}');
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? context}) {
    _logger.severe('$message ${_formatContext(context)}', error, stackTrace);
  }

  @override
  void debug(String message, {Map<String, dynamic>? context}) {
    _logger.fine('$message ${_formatContext(context)}');
  }

  String _formatContext(Map<String, dynamic>? context) {
    return context != null ? '| Context: ${context.toString()}' : '';
  }
}
