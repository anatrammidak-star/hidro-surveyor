MODEL_VERSION = "vision-v0-mock"


def analyze_media(media_items: list) -> dict:
    return {
        "status": "INSUFFICIENT_EVIDENCE",
        "model_version": MODEL_VERSION,
        "quality_score": 0.0,
        "confidence_level": "UNAVAILABLE",
        "evidence_count": 0,
        "reference_used": False,
        "precision_level": "SCREENING",
        "notes": (
            "Vision engine belum terhubung. "
            "Tidak ada estimasi AI yang dibuat."
        ),
        "visual_estimate": None,
        "evidence": {
            "water_detected": False,
            "reference_object_detected": False,
            "person_detected": False,
            "flow_surface_visible": False,
            "head_evidence": False,
        },
    }
