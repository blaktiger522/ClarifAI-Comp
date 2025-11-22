from fastapi import APIRouter, UploadFile, File, HTTPException, Form, Request
from fastapi.responses import JSONResponse
from PIL import Image
import io
import logging
import time
import os
from typing import Optional
import asyncio
from model_loader import ModelLoader

logger = logging.getLogger(__name__)

# Initialize router
router = APIRouter()

# Constants
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
SUPPORTED_FORMATS = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
MIN_DIMENSION = 100
MAX_DIMENSION = 4096
MAX_OUTPUT_LENGTH = 5000

# Rate limiting (simple in-memory store)
rate_limiter = {}
RATE_LIMIT_REQUESTS = 10  # requests per minute
RATE_LIMIT_WINDOW = 60  # seconds

async def get_rate_limited_client_ip(request: Request) -> str:
    """Get client IP for rate limiting"""
    # Check various headers for real IP
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()

    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip

    return request.client.host if request.client else "unknown"

async def check_rate_limit(client_ip: str) -> bool:
    """Check if client has exceeded rate limit"""
    current_time = int(time.time())

    if client_ip not in rate_limiter:
        rate_limiter[client_ip] = []

    # Remove old requests outside the window
    rate_limiter[client_ip] = [
        req_time for req_time in rate_limiter[client_ip]
        if current_time - req_time < RATE_LIMIT_WINDOW
    ]

    # Check if under limit
    if len(rate_limiter[client_ip]) < RATE_LIMIT_REQUESTS:
        rate_limiter[client_ip].append(current_time)
        return True

    return False

def validate_image(image: Image.Image) -> tuple[bool, str]:
    """Validate image dimensions and format"""
    width, height = image.size

    if width < MIN_DIMENSION or height < MIN_DIMENSION:
        return False, f"Image too small (minimum {MIN_DIMENSION}x{MIN_DIMENSION}px)"

    if width > MAX_DIMENSION or height > MAX_DIMENSION:
        return False, f"Image too large (maximum {MAX_DIMENSION}x{MAX_DIMENSION}px)"

    return True, "Valid"

def preprocess_image(image: Image.Image) -> Image.Image:
    """Preprocess image for OCR"""
    # Convert to RGB if necessary
    if image.mode != 'RGB':
        image = image.convert('RGB')

    # Resize if too large (maintain aspect ratio)
    width, height = image.size
    max_size = 1920

    if max(width, height) > max_size:
        if width > height:
            new_width = max_size
            new_height = int(height * max_size / width)
        else:
            new_height = max_size
            new_width = int(width * max_size / height)

        image = image.resize((new_width, new_height), Image.Resampling.LANCZOS)

    return image

@router.post("/process")
async def process_image(request: Request, file: UploadFile = File(...)):
    """
    Process an image and extract text using LightOnOCR

    Args:
        file: Image file (JPEG, PNG, WebP)

    Returns:
        JSON response with extracted text and metadata
    """
    start_time = time.time()

    try:
        # Rate limiting
        client_ip = await get_rate_limited_client_ip(request)
        if not await check_rate_limit(client_ip):
            raise HTTPException(
                status_code=429,
                detail="Too many requests. Please wait and try again."
            )

        # Validate file content type
        if file.content_type not in SUPPORTED_FORMATS:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported file format. Supported formats: {', '.join(SUPPORTED_FORMATS)}"
            )

        # Check file size
        if file.size and file.size > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=413,
                detail="File too large. Maximum size is 10MB"
            )

        # Read and validate file content
        try:
            contents = await file.read()
            if len(contents) > MAX_FILE_SIZE:
                raise HTTPException(
                    status_code=413,
                    detail="File too large. Maximum size is 10MB"
                )

            # Check if it's actually an image
            try:
                image = Image.open(io.BytesIO(contents))
                image.verify()  # Verify it's a valid image
                image = Image.open(io.BytesIO(contents))  # Reopen after verify
            except Exception as e:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid image file or corrupted image"
                )
        except Exception as e:
            if isinstance(e, HTTPException):
                raise e
            raise HTTPException(
                status_code=400,
                detail="Failed to read uploaded file"
            )

        # Validate image dimensions
        is_valid, validation_message = validate_image(image)
        if not is_valid:
            raise HTTPException(
                status_code=400,
                detail=validation_message
            )

        # Preprocess image
        processed_image = preprocess_image(image)

        # Get model loader (should be initialized in main.py)
        from main import model_loader

        if not model_loader or not model_loader.is_loaded:
            raise HTTPException(
                status_code=503,
                detail="OCR service temporarily unavailable"
            )

        # Process image with model
        try:
            result = await model_loader.process_image(processed_image, max_length=MAX_OUTPUT_LENGTH)
            extracted_text = result.get('text', '').strip()

            # Check if any text was extracted
            if not extracted_text:
                return JSONResponse(
                    status_code=200,
                    content={
                        "success": True,
                        "text": "",
                        "confidence": 0.0,
                        "processing_time_ms": int((time.time() - start_time) * 1000),
                        "message": "No readable text found in image"
                    }
                )

            return JSONResponse(
                status_code=200,
                content={
                    "success": True,
                    "text": extracted_text,
                    "confidence": result.get('confidence', 0.95),
                    "processing_time_ms": int((time.time() - start_time) * 1000)
                }
            )

        except Exception as e:
            logger.error(f"OCR processing error: {e}")
            raise HTTPException(
                status_code=500,
                detail="Failed to process image. Please try again."
            )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in process_image: {e}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )

@router.get("/info")
async def get_ocr_info():
    """Get information about the OCR service"""
    try:
        from main import model_loader

        info = {
            "service": "ClarifAI OCR API",
            "model": "LightOnOCR-1B-1025",
            "supported_formats": SUPPORTED_FORMATS,
            "max_file_size_mb": MAX_FILE_SIZE // (1024 * 1024),
            "max_image_dimension": MAX_DIMENSION,
            "rate_limit": {
                "requests_per_minute": RATE_LIMIT_REQUESTS,
                "window_seconds": RATE_LIMIT_WINDOW
            }
        }

        if model_loader:
            memory_info = model_loader.get_memory_info()
            info.update({
                "model_loaded": model_loader.is_loaded,
                "device": memory_info.get("device"),
                "memory_info": memory_info
            })
        else:
            info["model_loaded"] = False

        return info

    except Exception as e:
        logger.error(f"Error getting OCR info: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to get service information"
        )

@router.post("/test")
async def test_ocr_endpoint():
    """Test endpoint for debugging"""
    return {
        "success": True,
        "message": "OCR endpoint is working",
        "timestamp": time.time()
    }