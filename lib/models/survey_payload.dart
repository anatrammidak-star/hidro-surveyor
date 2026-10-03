class SurveyReportPayload {
  final String surveyMode; // 'HYDRO_POWER' atau 'DISCHARGE_ONLY'
  final String namaUpt;
  final String bidangSeksi;
  final DateTime waktuSurvey;
  final String namaSungaiTerjun;
  final double latitude;
  final double longitude;
  final double altitudeGps;
  final String namaPenanggungJawab;
  final String nipPenanggungJawab;
  final String? signatureImagePath;

  final double riverWidthM;
  final double depthEstimateM;
  final double surfaceVelocityMps;
  final double meanVelocityMps;
  final double crossSectionAreaSqm;
  final double dischargeCms;

  final double? grossHeadM;
  final double? netHeadM;
  final double? powerOutputKw;
  final String? recommendedTurbine;

  final String photoPath;
  final String videoPath;

  SurveyReportPayload({
    required this.surveyMode,
    required this.namaUpt,
    required this.bidangSeksi,
    required this.waktuSurvey,
    required this.namaSungaiTerjun,
    required this.latitude,
    required this.longitude,
    required this.altitudeGps,
    required this.namaPenanggungJawab,
    required this.nipPenanggungJawab,
    this.signatureImagePath,
    required this.riverWidthM,
    required this.depthEstimateM,
    required this.surfaceVelocityMps,
    required this.meanVelocityMps,
    required this.crossSectionAreaSqm,
    required this.dischargeCms,
    this.grossHeadM,
    this.netHeadM,
    this.powerOutputKw,
    this.recommendedTurbine,
    required this.photoPath,
    required this.videoPath,
  });

  bool get isDischargeOnly => surveyMode == 'DISCHARGE_ONLY';
}
