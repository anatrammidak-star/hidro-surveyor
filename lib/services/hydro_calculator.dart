class HydroCalculator {
  static const double gravity = 9.81;

  static Map<String, dynamic> compute({
    required String mode,
    required double width,
    required double depth,
    required double surfaceVelocity,
    double? grossHead,
  }) {
    final area = width * depth * 0.75;
    final vMean = surfaceVelocity * 0.85;
    final discharge = area * vMean;

    if (mode == 'DISCHARGE_ONLY' || grossHead == null) {
      return {
        'area': area,
        'vMean': vMean,
        'discharge': discharge,
        'netHead': null,
        'powerKw': null,
        'turbine': null,
      };
    }

    final netHead = grossHead * 0.92;
    final powerKw = gravity * discharge * netHead * 0.78 * 0.92;

    String turbine;
    if (netHead > 50) {
      turbine = 'Pelton / Turgo';
    } else if (netHead >= 15) {
      turbine = discharge > 1.2 ? 'Francis' : 'Turgo / Crossflow';
    } else if (netHead >= 3) {
      turbine = discharge > 0.6 ? 'Kaplan / Propeller' : 'Crossflow';
    } else {
      turbine = 'Archimedes Screw / Vortex';
    }

    return {
      'area': area,
      'vMean': vMean,
      'discharge': discharge,
      'netHead': netHead,
      'powerKw': powerKw,
      'turbine': turbine,
    };
  }
}
