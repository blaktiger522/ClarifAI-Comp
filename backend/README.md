# ClarifAI OCR Backend

FastAPI backend service for handwritten text recognition using LightOnOCR.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Copy environment configuration:
```bash
cp .env.example .env
```

3. Edit `.env` file with your settings.

## Running

Development:
```bash
python main.py
```

Production:
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1
```

## API Endpoints

- `POST /api/ocr/process` - Process image and extract text
- `GET /api/ocr/info` - Get service information
- `GET /health` - Health check
- `GET /docs` - API documentation

## Requirements

- Python 3.8+
- GPU recommended (NVIDIA with CUDA)
- 8GB+ RAM for GPU inference
- 16GB+ RAM for CPU inference