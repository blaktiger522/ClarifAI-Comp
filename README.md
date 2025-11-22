# ClarifAI - Handwriting to Text OCR App

A Flutter mobile application that converts handwritten text into clear, shareable digital text using OCR technology.

## Features

- 📸 **Camera Integration** - Capture photos of handwritten text using device camera
- 🖼️ **Gallery Support** - Select existing images from device gallery
- 🤖 **Advanced OCR** - Uses LightOnOCR-1B-1025 model for accurate text recognition
- ✏️ **Text Editing** - Edit and correct extracted text as needed
- 📋 **Copy & Share** - One-tap copy to clipboard and native sharing
- 🌐 **Offline Detection** - Real-time internet connectivity monitoring
- 🔐 **Privacy Focused** - No sensitive data stored locally

## Architecture

### Mobile App (Flutter)
- **Framework**: Flutter for cross-platform development
- **Target Platform**: Android (iOS support ready)
- **Language**: Dart
- **Key Libraries**: Camera, Image Picker, HTTP, Go Router

### Backend API (FastAPI)
- **Framework**: Python FastAPI
- **OCR Model**: LightOnOCR-1B-1025 from LightOn AI
- **Deployment**: GPU server for optimal performance
- **Features**: Rate limiting, error handling, image preprocessing

## Quick Start

### Prerequisites
- Flutter SDK (>=3.10.0)
- Android Studio / VS Code with Flutter extension
- Android device or emulator
- Python 3.8+ (for backend)

### Running the Mobile App

1. Clone the repository:
```bash
git clone <repository-url>
cd ClarifAI-Comp
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Running the Backend

1. Navigate to backend directory:
```bash
cd backend
```

2. Install Python dependencies:
```bash
pip install -r requirements.txt
```

3. Copy and configure environment:
```bash
cp .env.example .env
# Edit .env with your settings
```

4. Start the server:
```bash
python main.py
```

The API will be available at `http://localhost:8000`

## User Flow

1. **Launch App** → Clean main screen with capture options
2. **Take/Select Photo** → Camera interface or gallery picker
3. **Upload & Process** → Loading animation with "Converting handwriting..."
4. **View Results** → Clean text display with editing capability
5. **Copy/Share** → One-tap clipboard copy or native sharing
6. **Scan Again** → Easy return to camera for next scan

## API Documentation

Once the backend is running, visit `http://localhost:8000/docs` for interactive API documentation.

### Main Endpoint

**POST /api/ocr/process**
- Input: Image file (multipart/form-data)
- Output: JSON with extracted text and metadata

```json
{
  "success": true,
  "text": "Extracted text here...",
  "confidence": 0.94,
  "processing_time_ms": 2300
}
```

## Configuration

### Mobile App Configuration
- Camera permissions are automatically requested
- Internet connection is required for OCR processing
- Images are compressed before upload (max 5MB)

### Backend Configuration
Edit `backend/.env` to customize:
- Server host and port
- Model settings
- Rate limiting
- File size limits

## Error Handling

The app handles various error scenarios:
- Camera permission denied
- Network connectivity issues
- OCR service unavailable
- Invalid image formats
- Processing timeouts

## Performance

- **App Size**: <50MB
- **Startup Time**: <3 seconds
- **OCR Processing**: 2-5 seconds (depends on image complexity)
- **Supported Formats**: JPEG, PNG, WebP
- **Max Image Size**: 4096x4096px

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Create an issue in the repository
- Check the API documentation at `/docs`
- Review the troubleshooting guide