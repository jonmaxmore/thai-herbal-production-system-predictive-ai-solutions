import pytest
from fastapi.testclient import TestClient
from app.main import app
import os

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_assess_quality_no_image():
    response = client.post("/assess-quality")
    assert response.status_code == 422

def test_assess_quality_with_image():
    test_image_path = os.path.join(os.path.dirname(__file__), "test_herb.jpg")
    
    with open(test_image_path, "rb") as f:
        response = client.post(
            "/assess-quality",
            files={"image": ("test_herb.jpg", f, "image/jpeg")}
        )
    
    assert response.status_code == 200
    result = response.json()
    assert result["status"] == "success"
    assert 0 <= result["quality_score"] <= 1
    assert isinstance(result["defects"], list)
