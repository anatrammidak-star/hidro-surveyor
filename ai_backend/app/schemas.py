from typing import Literal
from pydantic import BaseModel, Field


class GPSData(BaseModel):
    latitude: float | None = None
    longitude: float | None = None
    altitude_m: float | None = None


class FieldInput(BaseModel):
    river_width_m: float | None = None
    depth_estimate_m: float | None = None
    surface_velocity_mps: float | None = None
    gross_head_m: float | None = None


class MediaInput(BaseModel):
    media_type: Literal[
        "PHOTO_FAR", "PHOTO_SCALE", "PHOTO_FLOW",
        "VIDEO_FLOW", "VIDEO_FLOAT",
        "PHOTO_OTHER", "VIDEO_OTHER"
    ]
    local_path: str | None = None
    server_url: str | None = None


class SurveyInput(BaseModel):
    local_id: str
    survey_mode: Literal["HYDRO_POWER", "DISCHARGE_ONLY"]
    gps: GPSData = Field(default_factory=GPSData)
    field_input: FieldInput = Field(default_factory=FieldInput)
    media: list[MediaInput] = Field(default_factory=list)


class AnalysisRequest(BaseModel):
    contract_version: Literal["1.0"]
    survey: SurveyInput


class AIResult(BaseModel):
    status: str
    model_version: str
    quality_score: float = 0.0
    confidence_level: str = "UNAVAILABLE"
    evidence_count: int = 0
    reference_used: bool = False
    precision_level: str = "SCREENING"
    notes: str


class AnalysisResponse(BaseModel):
    contract_version: str = "1.0"
    ai: AIResult
    visual_estimate: dict | None = None
    evidence: dict
    warnings: list[str] = Field(default_factory=list)
