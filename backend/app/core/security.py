# app/core/security.py
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = await UserService.get_by_id(user_id)
    if user is None:
        raise credentials_exception
    return user

# app/api/endpoints/analysis.py
@router.post("/analyze", response_model=AnalysisResult)
async def analyze_image(
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    image_data = await image.read()
    result = await AnalysisService.process_image(image_data)
    
    # Log analysis request
    await AuditLogService.create(
        user_id=current_user.id,
        action="image_analysis",
        details=f"Herb type: {result.herb_type}"
    )
    
    return result
