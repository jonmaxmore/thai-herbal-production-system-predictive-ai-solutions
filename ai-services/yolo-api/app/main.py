from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import torch
from PIL import Image
import io
import numpy as np
import logging
from pydantic import BaseModel

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Thai Herbal Quality Assessment API",
    version="1.0.0",
    description="API for assessing Thai herbal quality using computer vision"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load model
try:
    model = torch.hub.load('ultralytics/yolov5', 'custom', path='best.pt')
    logger.info("Model loaded successfully")
except Exception as e:
    logger.error(f"Error loading model: {e}")
    model = None

class DetectionResult(BaseModel):
    class_name: str
    confidence: float
    xmin: int
    ymin: int
    xmax: int
    ymax: int

class QualityResponse(BaseModel):
    status: str
    quality_score: float
    defects: list[DetectionResult]

@app.post("/assess-quality", response_model=QualityResponse)
async def assess_quality(image: UploadFile = File(...)):
    try:
        if not model:
            return {"status": "error", "message": "Model not loaded"}
        
        # Read image
        image_data = await image.read()
        img = Image.open(io.BytesIO(image_data)).convert('RGB')
        
        # Process image
        results = model(img)
        
        # Parse results
        detections = []
        quality_score = 1.0
        
        for result in results.pandas().xyxy[0].to_dict(orient='records'):
            detection = DetectionResult(
                class_name=result['name'],
                confidence=result['confidence'],
                xmin=int(result['xmin']),
                ymin=int(result['ymin']),
                xmax=int(result['xmax']),
                ymax=int(result['ymax'])
            )
            detections.append(detection)
            
            # Deduct for defects
            if 'defect' in result['name'].lower():
                quality_score -= 0.1 * result['confidence']
        
        quality_score = max(0.0, min(quality_score, 1.0))
        
        return QualityResponse(
            status="success",
            quality_score=round(quality_score, 2),
            defects=detections
        )
        
    except Exception as e:
        logger.exception("Error processing image")
        return {"status": "error", "message": str(e)}

@app.get("/health")
async def health_check():
    return {"status": "ok", "model_loaded": bool(model)}
