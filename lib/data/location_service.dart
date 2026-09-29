import 'dart:async';

import 'package:geolocator/geolocator.dart';

sealed class LocationResult {
  const LocationResult();
}

final class LocationFound extends LocationResult {
  const LocationFound(this.lat, this.lon);
  final double lat, lon;
}

/// Az engedélyt most megtagadták (újra kérhető).
final class LocationDenied extends LocationResult {
  const LocationDenied();
}

/// Végleg megtagadva: csak a rendszerbeállításokban kapcsolható be.
final class LocationDeniedForever extends LocationResult {
  const LocationDeniedForever();
}

final class LocationServiceOff extends LocationResult {
  const LocationServiceOff();
}

final class LocationUnavailable extends LocationResult {
  const LocationUnavailable();
}

abstract interface class LocationService {
  /// Csak használat közbeni engedélyt kér.
  Future<LocationResult> current();
  Future<void> openSettings();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationResult> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationServiceOff();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        return const LocationDenied();
      case LocationPermission.deniedForever:
        return const LocationDeniedForever();
      case LocationPermission.unableToDetermine:
        return const LocationUnavailable();
      case LocationPermission.whileInUse || LocationPermission.always:
        break;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationFound(position.latitude, position.longitude);
    } on TimeoutException {
      return const LocationUnavailable();
    } on LocationServiceDisabledException {
      return const LocationServiceOff();
    }
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}
