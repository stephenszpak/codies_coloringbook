sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String message;
  final Exception? exception;
  
  const Failure(this.message, [this.exception]);
}

extension ResultExtension<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  
  T? get dataOrNull => isSuccess ? (this as Success<T>).data : null;
  String? get errorMessage => isFailure ? (this as Failure<T>).message : null;
  
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(String message) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final data) => onSuccess(data),
      Failure<T>(:final message) => onFailure(message),
    };
  }
}