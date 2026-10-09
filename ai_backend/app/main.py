from fastapi import FastAPI, HTTPException

from app.schemas import AnalysisRequest, AnalysisResponse
from app.validator import validate_request
from app.services.vision import analyze_media

app = FastAPI(
    title="SiCA AI Engineering API",
    version="0.1.0",
    description="API awal untuk analisis data survei sungai SiCA.",
)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "sica-ai-backend",
        "api_version": "0.1.0",
    }


@app.post("/api/v1/analyze", response_model=AnalysisResponse)
def analyze(request: AnalysisRequest):
    try:
        warnings = validate_request(request)
        result = analyze_media(request.survey.media)

        return AnalysisResponse(
            contract_version="1.0",
            ai={
                key: result[key]
                for key in (
                    "status",
                    "model_version",
                    "quality_score",
                    "confidence_level",
                    "evidence_count",
                    "reference_used",
                    "precision_level",
                    "notes",
                )
            },
            visual_estimate=result["visual_estimate"],
            evidence=result["evidence"],
            warnings=warnings,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        ) from exc
