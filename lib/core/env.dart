/// Fordítási idejű konfiguráció (`--dart-define-from-file=env.json`).
class Env {
  const Env._();

  static const futarApiKey = String.fromEnvironment('FUTAR_API_KEY');
}
