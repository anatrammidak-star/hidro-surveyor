from app.schemas import AnalysisRequest


def validate_request(request: AnalysisRequest) -> list[str]:
    warnings = []

    survey = request.survey

    if not survey.media:
        warnings.append("Tidak ada media dokumentasi.")

    gps = survey.gps
    if gps.latitude is None or gps.longitude is None:
        warnings.append("Koordinat GPS belum tersedia.")

    field = survey.field_input
    if (
        field.river_width_m is None
        or field.depth_estimate_m is None
        or field.surface_velocity_mps is None
    ):
        warnings.append(
            "Data lapangan belum lengkap untuk estimasi debit berbasis pengukuran."
        )

    return warnings
