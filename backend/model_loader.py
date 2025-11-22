import torch
from transformers import AutoProcessor, AutoModelForVision2Seq
import logging
from typing import Optional
import asyncio
from concurrent.futures import ThreadPoolExecutor
import gc

logger = logging.getLogger(__name__)

class ModelLoader:
    """
    Handles loading and inference with LightOnOCR-1B-1025 model
    """

    def __init__(self):
        self.model = None
        self.processor = None
        self.device = None
        self.is_loaded = False
        self.executor = ThreadPoolExecutor(max_workers=2)
        self.model_name = "lightonai/LightOnOCR-1B-1025"

    async def initialize(self):
        """Initialize the model and processor"""
        try:
            # Detect device
            if torch.cuda.is_available():
                self.device = "cuda"
                logger.info(f"Using CUDA device: {torch.cuda.get_device_name()}")
            else:
                self.device = "cpu"
                logger.warning("CUDA not available, using CPU (slower inference)")

            # Load model in separate thread to avoid blocking
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(self.executor, self._load_model_sync)

            self.is_loaded = True
            logger.info("LightOnOCR model loaded successfully")

        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            raise RuntimeError(f"Model loading failed: {str(e)}")

    def _load_model_sync(self):
        """Load model synchronously"""
        try:
            logger.info(f"Loading model {self.model_name}...")

            # Load processor
            self.processor = AutoProcessor.from_pretrained(self.model_name)
            logger.info("Processor loaded successfully")

            # Load model with appropriate settings
            self.model = AutoModelForVision2Seq.from_pretrained(
                self.model_name,
                torch_dtype=torch.float16 if self.device == "cuda" else torch.float32,
                device_map="auto" if self.device == "cuda" else None,
                low_cpu_mem_usage=True
            )

            # Move to device if not using device_map
            if self.device == "cpu":
                self.model = self.model.to(self.device)

            # Set to evaluation mode
            self.model.eval()

            # Enable memory optimizations
            if self.device == "cuda":
                # Enable gradient checkpointing to save memory
                self.model.gradient_checkpointing_enable()

                # Use inference mode
                with torch.inference_mode():
                    pass

            logger.info("Model loaded successfully")

        except Exception as e:
            logger.error(f"Error loading model: {e}")
            raise

    async def process_image(self, image, max_length: int = 512) -> dict:
        """
        Process image and extract text using LightOnOCR

        Args:
            image: PIL Image object
            max_length: Maximum output text length

        Returns:
            dict with extracted text and metadata
        """
        if not self.is_loaded or self.model is None or self.processor is None:
            raise RuntimeError("Model not loaded")

        try:
            # Run inference in separate thread
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                self.executor,
                self._process_image_sync,
                image,
                max_length
            )
            return result

        except Exception as e:
            logger.error(f"Error processing image: {e}")
            raise RuntimeError(f"Inference failed: {str(e)}")

    def _process_image_sync(self, image, max_length: int) -> dict:
        """Process image synchronously"""
        try:
            import time
            start_time = time.time()

            # Prepare inputs
            messages = [
                {
                    "role": "user",
                    "content": [
                        {"type": "image", "image": image},
                        {"type": "text", "text": "Extract all the text from this image."}
                    ]
                }
            ]

            # Create prompt
            prompt = self.processor.apply_chat_template(messages, tokenize=False)

            # Process inputs
            inputs = self.processor(
                text=prompt,
                images=[image],
                return_tensors="pt"
            )

            # Move inputs to device
            if self.device == "cuda":
                inputs = {k: v.to(self.device) for k, v in inputs.items()}

            # Generate text
            with torch.no_grad(), torch.inference_mode():
                outputs = self.model.generate(
                    **inputs,
                    max_new_tokens=max_length,
                    do_sample=False,
                    temperature=1.0,
                    pad_token_id=self.processor.tokenizer.pad_token_id,
                    eos_token_id=self.processor.tokenizer.eos_token_id,
                )

            # Decode output
            generated_text = self.processor.decode(outputs[0], skip_special_tokens=True)

            # Clean up the generated text (remove the prompt part)
            if "Extract all the text from this image." in generated_text:
                # Extract the response part after the instruction
                parts = generated_text.split("Extract all the text from this image.")
                if len(parts) > 1:
                    extracted_text = parts[1].strip()
                else:
                    extracted_text = generated_text.strip()
            else:
                extracted_text = generated_text.strip()

            # Additional cleanup
            extracted_text = self._clean_extracted_text(extracted_text)

            processing_time = (time.time() - start_time) * 1000  # Convert to milliseconds

            result = {
                "text": extracted_text,
                "processing_time_ms": int(processing_time),
                "confidence": 0.95  # LightOnOCR doesn't provide confidence scores
            }

            logger.info(f"Text extraction completed in {processing_time:.0f}ms")
            return result

        except Exception as e:
            logger.error(f"Error during inference: {e}")
            raise

    def _clean_extracted_text(self, text: str) -> str:
        """Clean and format the extracted text"""
        if not text:
            return ""

        # Remove any common artifacts
        text = text.strip()

        # Remove the original prompt if it appears in the output
        if "Extract all the text from this image." in text:
            text = text.split("Extract all the text from this image.")[-1].strip()

        # Remove common model artifacts
        artifacts = [
            "Here is the extracted text:",
            "The text in the image is:",
            "I can see the following text:",
        ]

        for artifact in artifacts:
            if text.startswith(artifact):
                text = text[len(artifact):].strip()

        return text

    async def cleanup(self):
        """Cleanup resources"""
        try:
            if self.model is not None:
                # Move model to CPU if on GPU
                if self.device == "cuda":
                    self.model.cpu()

                # Clear CUDA cache
                if torch.cuda.is_available():
                    torch.cuda.empty_cache()

                # Delete model and processor
                del self.model
                del self.processor

                # Force garbage collection
                gc.collect()

            # Shutdown executor
            if self.executor:
                self.executor.shutdown(wait=True)

            self.is_loaded = False
            logger.info("Model cleanup completed")

        except Exception as e:
            logger.error(f"Error during cleanup: {e}")

    def get_memory_info(self) -> dict:
        """Get memory usage information"""
        info = {
            "device": self.device,
            "model_loaded": self.is_loaded
        }

        if torch.cuda.is_available():
            info.update({
                "gpu_allocated": torch.cuda.memory_allocated() / 1024**3,  # GB
                "gpu_reserved": torch.cuda.memory_reserved() / 1024**3,     # GB
                "gpu_max_allocated": torch.cuda.max_memory_allocated() / 1024**3,  # GB
            })

        return info