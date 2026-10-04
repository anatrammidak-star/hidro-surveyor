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

  // ===========================================================
  // FIELD CORRECTION INPUT
  // Semua OPTIONAL
  // ===========================================================

  final double? riverWidthM;
  final double? depthEstimateM;
  final double? surfaceVelocityMps;
  final double? grossHeadM;

  // ===========================================================
  // DERIVED / LEGACY VALUES
  // ===========================================================

  final double? meanVelocityMps;
  final double? crossSectionAreaSqm;
  final double? dischargeCms;

  final double? netHeadM;
  final double? powerOutputKw;

  final String? recommendedTurbine;

  // ===========================================================
  // AI / VISUAL PREDICTION
  // ===========================================================

  final double? visualDischargeMinCms;
  final double? visualDischargeCms;
  final double? visualDischargeMaxCms;

  final double? visualHeadMinM;
  final double? visualHeadM;
  final double? visualHeadMaxM;

  final double? visualPowerMinKw;
  final double? visualPowerKw;
  final double? visualPowerMaxKw;

  // ===========================================================
  // FIELD CORRECTED / PRECISION ESTIMATION
  // ===========================================================

  final double? correctedDischargeMinCms;
  final double? correctedDischargeCms;
  final double? correctedDischargeMaxCms;

  final double? correctedHeadMinM;
  final double? correctedHeadM;
  final double? correctedHeadMaxM;

  final double? correctedPowerMinKw;
  final double? correctedPowerKw;
  final double? correctedPowerMaxKw;

  // ===========================================================
  // AI METADATA
  // ===========================================================

  final String? aiStatus;
  final String? aiModelVersion;

  final double? aiQualityScore;

  final DateTime? aiProcessedAt;

  final String? aiNotes;

  final int? aiEvidenceCount;

  // ===========================================================
  // REFERENCE / PRECISION
  // ===========================================================

  final String? referenceUsed;
  final String? precisionLevel;

  // ===========================================================
  // CORRECTION FACTORS
  // ===========================================================

  final double? surfaceVelocityFactor;
  final double? headLossFactor;
  final double? turbineEfficiency;

  final String? correctionProfile;

  // ===========================================================
  // GENERAL ESTIMATION
  // ===========================================================

  final String? estimationMethod;
  final String? confidenceLevel;

  final String? documentationStatus;

  // ===========================================================
  // SYNCHRONIZATION
  // ===========================================================

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

    // Field correction
    this.riverWidthM,
    this.depthEstimateM,
    this.surfaceVelocityMps,
    this.grossHeadM,

    // Derived
    this.meanVelocityMps,
    this.crossSectionAreaSqm,
    this.dischargeCms,

    this.netHeadM,
    this.powerOutputKw,

    this.recommendedTurbine,

    // AI visual prediction
    this.visualDischargeMinCms,
    this.visualDischargeCms,
    this.visualDischargeMaxCms,

    this.visualHeadMinM,
    this.visualHeadM,
    this.visualHeadMaxM,

    this.visualPowerMinKw,
    this.visualPowerKw,
    this.visualPowerMaxKw,

    // Corrected
    this.correctedDischargeMinCms,
    this.correctedDischargeCms,
    this.correctedDischargeMaxCms,

    this.correctedHeadMinM,
    this.correctedHeadM,
    this.correctedHeadMaxM,

    this.correctedPowerMinKw,
    this.correctedPowerKw,
    this.correctedPowerMaxKw,

    // AI metadata
    this.aiStatus,
    this.aiModelVersion,
    this.aiQualityScore,
    this.aiProcessedAt,
    this.aiNotes,
    this.aiEvidenceCount,

    // Reference / precision
    this.referenceUsed,
    this.precisionLevel,

    // Correction factors
    this.surfaceVelocityFactor,
    this.headLossFactor,
    this.turbineEfficiency,
    this.correctionProfile,

    // Estimation
    this.estimationMethod,
    this.confidenceLevel,
    this.documentationStatus,

    // Sync
    this.syncStatus = 'PENDING',
    this.syncAttempts = 0,
    this.lastSyncError,

    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDischargeOnly =>
      surveyMode == 'DISCHARGE_ONLY';

  bool get hasFieldCorrection {
    return riverWidthM != null ||
        depthEstimateM != null ||
        surfaceVelocityMps != null ||
        grossHeadM != null;
  }

  bool get hasPrecisionParameters {
    return riverWidthM != null &&
        depthEstimateM != null &&
        surfaceVelocityMps != null &&
        grossHeadM != null;
  }

  bool get hasAiPrediction {
    return visualDischargeCms != null ||
        visualHeadM != null ||
        visualPowerKw != null;
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,

      'expedition_id':
          expeditionId,

      'local_id':
          localId,

      'survey_mode':
          surveyMode,

      'nama_upt':
          namaUpt,

      'bidang_seksi':
          bidangSeksi,

      'waktu_survey':
          waktuSurvey.toIso8601String(),

      'nama_sungai':
          namaSungaiTerjun,

      'latitude':
          latitude,

      'longitude':
          longitude,

      'altitude_gps':
          altitudeGps,

      'nama_penanggung_jawab':
          namaPenanggungJawab,

      'nip_penanggung_jawab':
          nipPenanggungJawab,

      // -------------------------------------------------------
      // FIELD INPUT
      // -------------------------------------------------------

      'river_width_m':
          riverWidthM,

      'depth_estimate_m':
          depthEstimateM,

      'surface_velocity_mps':
          surfaceVelocityMps,

      'gross_head_m':
          grossHeadM,

      // -------------------------------------------------------
      // DERIVED
      // -------------------------------------------------------

      'mean_velocity_mps':
          meanVelocityMps,

      'cross_section_area_sqm':
          crossSectionAreaSqm,

      'discharge_cms':
          dischargeCms,

      'net_head_m':
          netHeadM,

      'power_output_kw':
          powerOutputKw,

      'recommended_turbine':
          recommendedTurbine,

      // -------------------------------------------------------
      // AI VISUAL
      // -------------------------------------------------------

      'visual_discharge_min_cms':
          visualDischargeMinCms,

      'visual_discharge_cms':
          visualDischargeCms,

      'visual_discharge_max_cms':
          visualDischargeMaxCms,

      'visual_head_min_m':
          visualHeadMinM,

      'visual_head_m':
          visualHeadM,

      'visual_head_max_m':
          visualHeadMaxM,

      'visual_power_min_kw':
          visualPowerMinKw,

      'visual_power_kw':
          visualPowerKw,

      'visual_power_max_kw':
          visualPowerMaxKw,

      // -------------------------------------------------------
      // CORRECTED
      // -------------------------------------------------------

      'corrected_discharge_min_cms':
          correctedDischargeMinCms,

      'corrected_discharge_cms':
          correctedDischargeCms,

      'corrected_discharge_max_cms':
          correctedDischargeMaxCms,

      'corrected_head_min_m':
          correctedHeadMinM,

      'corrected_head_m':
          correctedHeadM,

      'corrected_head_max_m':
          correctedHeadMaxM,

      'corrected_power_min_kw':
          correctedPowerMinKw,

      'corrected_power_kw':
          correctedPowerKw,

      'corrected_power_max_kw':
          correctedPowerMaxKw,

      // -------------------------------------------------------
      // AI METADATA
      // -------------------------------------------------------

      'ai_status':
          aiStatus,

      'ai_model_version':
          aiModelVersion,

      'ai_quality_score':
          aiQualityScore,

      'ai_processed_at':
          aiProcessedAt
              ?.toIso8601String(),

      'ai_notes':
          aiNotes,

      'ai_evidence_count':
          aiEvidenceCount,

      // -------------------------------------------------------
      // REFERENCE
      // -------------------------------------------------------

      'reference_used':
          referenceUsed,

      'precision_level':
          precisionLevel,

      // -------------------------------------------------------
      // CORRECTION FACTORS
      // -------------------------------------------------------

      'surface_velocity_factor':
          surfaceVelocityFactor,

      'head_loss_factor':
          headLossFactor,

      'turbine_efficiency':
          turbineEfficiency,

      'correction_profile':
          correctionProfile,

      // -------------------------------------------------------
      // ESTIMATION
      // -------------------------------------------------------

      'estimation_method':
          estimationMethod,

      'confidence_level':
          confidenceLevel,

      'documentation_status':
          documentationStatus,

      // -------------------------------------------------------
      // SYNC
      // -------------------------------------------------------

      'sync_status':
          syncStatus,

      'sync_attempts':
          syncAttempts,

      'last_sync_error':
          lastSyncError,

      // -------------------------------------------------------
      // TIMESTAMP
      // -------------------------------------------------------

      'created_at':
          createdAt.toIso8601String(),

      'updated_at':
          updatedAt.toIso8601String(),
    };
  }
}
