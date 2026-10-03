class SurveyReportPayload {
  final int? id;
  final int expeditionId;
  final String localId;
  final String surveyMode;
  final String namaUpt;
  final String bidangSeksi;
  final DateTime waktuSurvey;
  final String namaSungaiTerjun;
  final double latitude;
  final double longitude;
  final double altitudeGps;
  final String namaPenanggungJawab;
  final String nipPenanggungJawab;

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

  final String syncStatus;
  final int syncAttempts;
  final String? lastSyncError;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SurveyReportPayload({
    this.id,
    required this.expeditionId,
    required this.localId,
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
    this.syncStatus = 'PENDING',
    this.syncAttempts = 0,
    this.lastSyncError,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDischargeOnly => surveyMode == 'DISCHARGE_ONLY';

  Map<String, Object?> toMap() => {
        'id': id,
        'expedition_id': expeditionId,
        'local_id': localId,
        'survey_mode': surveyMode,
        'nama_upt': namaUpt,
        'bidang_seksi': bidangSeksi,
        'waktu_survey': waktuSurvey.toIso8601String(),
        'nama_sungai': namaSungaiTerjun,
        'latitude': latitude,
        'longitude': longitude,
        'altitude_gps': altitudeGps,
        'nama_penanggung_jawab': namaPenanggungJawab,
        'nip_penanggung_jawab': nipPenanggungJawab,
        'river_width_m': riverWidthM,
        'depth_estimate_m': depthEstimateM,
        'surface_velocity_mps': surfaceVelocityMps,
        'mean_velocity_mps': meanVelocityMps,
        'cross_section_area_sqm': crossSectionAreaSqm,
        'discharge_cms': dischargeCms,
        'gross_head_m': grossHeadM,
        'net_head_m': netHeadM,
        'power_output_kw': powerOutputKw,
        'recommended_turbine': recommendedTurbine,
        'sync_status': syncStatus,
        'sync_attempts': syncAttempts,
        'last_sync_error': lastSyncError,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
