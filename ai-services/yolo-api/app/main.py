from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import torch
from PIL import Image
import io
import numpy as np
import logging
import os
import time
import cv2
import base64
from pydantic import BaseModel

# Production configuration
PRODUCTION = os.getenv("PRODUCTION", "false").lower() == "true"
MODEL_PATH = os.getenv("MODEL_PATH", "/app/models/best.pt")

app = FastAPI(
    title="Thai Herbal Quality Assessment API",
    version="1.0.0",
    description="API for computer vision-based quality assessment of Thai herbs"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("yolo-api")

# Load model
model = None
def load_model():
    global model
    try:
        start_time = time.time()
        model = torch.hub.load(
            'ultralytics/yolov5', 
            'custom', 
            path=MODEL_PATH,
            force_reload=True
        )
        if PRODUCTION:
            model = model.half()  # Use half-precision for faster inference
        load_time = time.time() - start_time
        logger.info(f"Model loaded in {load_time:.2f} seconds")
    except Exception as e:
        logger.error(f"Model loading failed: {str(e)}")
        model = None

load_model()

# Request and response models
class QualityRequest(BaseModel):
    image: str  # base64 encoded image

class Defect(BaseModel):
    type: str
    confidence: float
    xmin: int
    ymin: int
    xmax: int
    ymax: int

class QualityResponse(BaseModel):
    status: str
    processing_time: float
    quality_score: float
    detected_herb: str
    defects: list[Defect]
    recommendations: list[str]

# Health check endpoint
@app.get("/health")
def health_check():
    return {
        "status": "ok" if model else "unhealthy",
        "model_loaded": bool(model),
        "production": PRODUCTION
    }

# Main quality assessment endpoint
@app.post("/assess", response_model=QualityResponse)
async def assess_quality(request: QualityRequest):
    start_time = time.time()
    
    if not model:
        raise HTTPException(
            status_code=503, 
            detail="Model not loaded, service unavailable"
        )
    
    try:
        # Decode base64 image
        image_data = base64.b64decode(request.image.split(",")[-1])
        img = Image.open(io.BytesIO(image_data)).convert('RGB')
        img_np = np.array(img)
        
        # Preprocess for model
        img_rgb = cv2.cvtColor(img_np, cv2.COLOR_BGR2RGB)
        
        # Run inference
        results = model(img_rgb, size=640)
        
        # Process results
        defects = []
        quality_score = 1.0
        herb_type = "unknown"
        
        for result in results.pandas().xyxy[0].to_dict(orient="records"):
            defect = Defect(
                type=result["name"],
                confidence=result["confidence"],
                xmin=int(result["xmin"]),
                ymin=int(result["ymin"]),
                xmax=int(result["xmax"]),
                ymax=int(result["ymax"])
            )
            defects.append(defect)
            
            # Determine herb type if not set
            if herb_type == "unknown" and "herb" in defect.type:
                herb_type = defect.type.replace("herb_", "")
            
            # Deduct for defects
            if "defect" in defect.type:
                quality_score -= 0.15 * defect.confidence
        
        quality_score = max(0.0, min(quality_score, 1.0))
        
        # Generate recommendations
        recommendations = []
        if quality_score < 0.8:
            recommendations.append("ตรวจสอบกระบวนการเก็บเกี่ยวและอบแห้ง")
        if any(d.type == "fungus" for d in defects):
            recommendations.append("ปรับปรุงการควบคุมความชื้นในกระบวนการผลิต")
        
        processing_time = time.time() - start_time
        
        return QualityResponse(
            status="success",
            processing_time=round(processing_time, 3),
            quality_score=round(quality_score, 2),
            detected_herb=herb_type,
            defects=defects,
            recommendations=recommendations
        )
        
    except Exception as e:
        logger.error(f"Processing failed: {str(e)}")
        raise HTTPException(
            status_code=500, 
            detail=f"Image processing error: {str(e)}"
        )

# Model reload endpoint for production
@app.post("/reload-model")
def reload_model():
    if not PRODUCTION:
        load_model()
        return {"status": "reloaded"}
    return {"status": "disabled in production"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=8000,
        workers=4 if PRODUCTION else 1
    )
