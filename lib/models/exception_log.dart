class ExceptionLog {
  final String dataCode;
  final String? userId;
  final String? userInput;
  final String errorMessage;
  final String occuredAt;
  final String stringException;
  final String? stackTrace;
  final String? innerException;
  final String? methodName;
  final String? className;

  ExceptionLog({
    required this.dataCode,
    this.userId,
    this.userInput,
    required this.errorMessage,
    required this.occuredAt,
    required this.stringException,
    this.stackTrace,
    this.innerException,
    this.methodName,
    this.className,
  });

  Map<String, dynamic> toJson() {
    return {
      "DataCode": dataCode,
      "UserId": userId,
      "UserInput": userInput,
      "ErrorMessage": errorMessage,
      "OccuredAt": occuredAt,
      "StringException": stringException,
      "StackTrace": stackTrace,
      "InnerException": innerException,
      "MethodName": methodName,
      "ClassName": className,
    };
  }

  @override
  String toString() {
    return '''
  DataCode: $dataCode,
  UserId: $userId,
  UserInput: $userInput,
  ErrorMessage: $errorMessage,
  OccuredAt: $occuredAt,
  StringException: $stringException,
  StackTrace: $stackTrace,
  InnerException: $innerException,
  MethodName: $methodName,
  ClassName: $className
''';
  }
}
