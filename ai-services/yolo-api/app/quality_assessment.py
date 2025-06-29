import time
import logging
import cv2
import numpy as np
import torch
from PIL import Image
from io import BytesIO
from pydantic import BaseModel
from typing import List, Optional
from .model_loader import load_model
from ..utils.image_processing import preprocess_image, detect_defects
from ..config import settings

logger = logging.getLogger(__name__)

class Defect(BaseModel):
    type: str
    confidence: float
    xmin: int
    ymin: int
    xmax: int
    ymax: int

class QualityAssessmentResult(BaseModel):
    herb_type: str
    quality_score: float
    defects: List[Defect]
    recommendations: List[str]
    processing_time: float

class QualityAssessmentService:
    def __init__(self):
        self.model = load_model(settings.MODEL_PATH)
        self.herb_classes = settings.HERB_CLASSES
        self.defect_classes = settings.DEFECT_CLASSES
        self.min_confidence = settings.MIN_CONFIDENCE

    def assess_quality(self, image_data: bytes) -> QualityAssessmentResult:
        start_time = time.time()
        
        try:
            # Preprocess image
            img = self._load_image(image_data)
            processed_img = preprocess_image(img)
            
            # Run inference
            results = self.model(processed_img, size=640)
            pandas_results = results.pandas().xyxy[0]
            
            # Process results
            herb_type = "unknown"
            defects = []
            
            for _, row in pandas_results.iterrows():
                if row['confidence'] < self.min_confidence:
                    continue
                    
                if row['name'] in self.herb_classes:
                    herb_type = row['name']
                elif row['name'] in self.defect_classes:
                    defect = Defect(
                        type=row['name'],
                        confidence=row['confidence'],
                        xmin=int(row['xmin']),
                        ymin=int(row['ymin']),
                        xmax=int(row['xmax']),
                        ymax=int(row['ymax'])
                    )
                    defects.append(defect)
            
            # Calculate quality score
            quality_score = self._calculate_quality_score(defects)
            
            # Generate recommendations
            recommendations = self._generate_recommendations(quality_score, defects)
            
            # Calculate processing time
            processing_time = time.time() - start_time
            
            return QualityAssessmentResult(
                herb_type=herb_type,
                quality_score=quality_score,
                defects=defects,
                recommendations=recommendations,
                processing_time=processing_time
            )
            
        except Exception as e:
            logger.error(f"Quality assessment failed: {str(e)}")
            raise

    def _load_image(self, image_data: bytes) -> np.ndarray:
        try:
            img = Image.open(BytesIO(image_data)).convert('RGB')
            return np.array(img)
        except Exception as e:
            logger.error(f"Image loading failed: {str(e)}")
            raise ValueError("Invalid image data")

    def _calculate_quality_score(self, defects: List[Defect]) -> float:
        """Calculate quality score based on detected defects"""
        base_score = 1.0
        for defect in defects:
            # Deduct points based on defect type and confidence
            if defect.type == 'fungus':
                base_score -= 0.3 * defect.confidence
            elif defect.type == 'discoloration':
                base_score -= 0.2 * defect.confidence
            elif defect.type == 'size_variation':
                base_score -= 0.15 * defect.confidence
            else:
                base_score -= 0.1 * defect.confidence
        
        # Ensure score is between 0 and 1
        return max(0.0, min(1.0, base_score))

    def _generate_recommendations(self, quality_score: float, defects: List[Defect]) -> List[str]:
        """Generate recommendations based on quality issues"""
        recommendations = []
        
        if quality_score < 0.7:
            recommendations.append("Improve drying process to reduce moisture")
        
        if any(d.type == 'fungus' for d in defects):
            recommendations.append("Implement better storage humidity control")
        
        if any(d.type == 'discoloration' for d in defects):
            recommendations.append("Adjust harvesting time to avoid sun damage")
        
        if quality_score < 0.5:
            recommendations.append("Re-evaluate cultivation practices with agricultural expert")
        
        if not recommendations:
            recommendations.append("Quality meets standards, maintain current practices")
        
        return recommendations
