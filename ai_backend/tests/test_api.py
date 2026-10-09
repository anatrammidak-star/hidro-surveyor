from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_analysis_does_not_fabricate_ai_estimates():
    payload = {
        "contract_version": "1.0",
        "survey": {
            "local_id": "SUR-TEST-001",
            "survey_mode": "HYDRO_POWER",
            "gps": {
                "latitude": -6.2,
                "longitude": 106.8,
                "altitude_m": 100.0,
            },
            "field_input": {
                "river_width_m": None,
                "depth_estimate_m": None,
                "surface_velocity_mps": None,
                "gross_head_m": None,
            },
            "media": [],
        },
    }

    response = client.post("/api/v1/analyze", json=payload)

    assert response.status_code == 200

    body = response.json()
    assert body["ai"]["status"] == "INSUFFICIENT_EVIDENCE"
    assert body["visual_estimate"] is None
    assert body["ai"]["confidence_level"] == "UNAVAILABLE"


def test_invalid_contract_version():
    payload = {
        "contract_version": "99.0",
        "survey": {
            "local_id": "SUR-TEST-002",
            "survey_mode": "HYDRO_POWER",
        },
    }

    response = client.post("/api/v1/analyze", json=payload)

    assert response.status_code == 422
