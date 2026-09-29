/// Siker vagy típusos hiba; `switch`-csel kezelendő.
sealed class Result<T, E extends Object> {
  const Result();
}

final class Ok<T, E extends Object> extends Result<T, E> {
  const Ok(this.value);
  final T value;
}

final class Err<T, E extends Object> extends Result<T, E> {
  const Err(this.error);
  final E error;
}
