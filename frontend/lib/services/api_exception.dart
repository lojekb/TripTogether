enum ApiExceptionKind {
  validation,
  provider,
  timeout,
  network,
  unknown,
}

class ApiException implements Exception {
  final ApiExceptionKind kind;
  final int? statusCode;
  final String message;

  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => 'ApiException(kind: $kind, statusCode: $statusCode, message: $message)';

  static ApiException validation({int? statusCode, String message = 'Invalid request.'}) {
    return ApiException(kind: ApiExceptionKind.validation, statusCode: statusCode, message: message);
  }

  static ApiException provider({int? statusCode, String message = 'Provider error. Please try again.'}) {
    return ApiException(kind: ApiExceptionKind.provider, statusCode: statusCode, message: message);
  }

  static ApiException timeout({String message = 'Request timed out. Please try again.'}) {
    return ApiException(kind: ApiExceptionKind.timeout, message: message);
  }

  static ApiException network({String message = 'Network error. Please try again.'}) {
    return ApiException(kind: ApiExceptionKind.network, message: message);
  }

  static ApiException unknown({int? statusCode, String message = 'Unexpected error.'}) {
    return ApiException(kind: ApiExceptionKind.unknown, statusCode: statusCode, message: message);
  }
}
