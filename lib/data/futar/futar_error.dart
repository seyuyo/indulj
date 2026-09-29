// A Futár-hívások hibái. Egyik sem tartalmaz URL-t vagy kulcsot.

sealed class FutarError {
  const FutarError();
}

/// Nincs hálózat, időtúllépés, megszakadt kapcsolat.
final class NetworkError extends FutarError {
  const NetworkError(this.kind);

  /// Csak a kivétel típusa (pl. `SocketException`), az üzenete nem:
  /// az tartalmazhatja a kérés URL-jét.
  final String kind;

  @override
  String toString() => 'NetworkError($kind)';
}

/// Nem 200-as HTTP-válasz. 401 = érvénytelen kulcs.
final class HttpError extends FutarError {
  const HttpError(this.status);
  final int status;

  bool get isUnauthorized => status == 401 || status == 403;

  @override
  String toString() => 'HttpError($status)';
}

/// HTTP 200, de a burok hibát jelez (`code` / `status`).
final class ApiError extends FutarError {
  const ApiError(this.code, this.text);
  final int code;
  final String? text;

  @override
  String toString() => 'ApiError($code, $text)';
}

/// A válasz nem az elvárt szerkezetű.
final class ParseError extends FutarError {
  const ParseError(this.message);
  final String message;

  @override
  String toString() => 'ParseError($message)';
}
