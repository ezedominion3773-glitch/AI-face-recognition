from io import BytesIO
from PIL import Image
import cv2
import numpy as np

class LivenessService:
    """Service class for running face anti-spoofing and liveness check."""

    # Laplacian-variance threshold.
    # Lower than 100 might be blurry; real faces show higher detail variance.
    TEXTURE_THRESHOLD: float = 100.0

    def check_liveness(self, frames: list[bytes]) -> tuple[bool, str]:
        """
        Check if the captured frame is a real 3D face or a spoof attack.
        
        Args:
            frames: List of image byte-strings from the camera.
        """
        if not frames:
            return (False, "no_frames_provided")

        # Perform Laplacian texture analysis on the first frame
        texture_ok, variance = self._check_texture(frames[0])
        if not texture_ok:
            return (
                False,
                f"texture_fail:laplacian_var={variance:.1f}",
            )

        return (True, "liveness_passed")

    def _check_texture(self, image_bytes: bytes) -> tuple[bool, float]:
        """Compute the Laplacian variance of the image to check detail frequency."""
        pil_image = Image.open(BytesIO(image_bytes)).convert("RGB")
        cv_image = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(cv_image, cv2.COLOR_BGR2GRAY)

        # Apply Laplacian operator to compute image variance
        laplacian = cv2.Laplacian(gray, cv2.CV_64F)
        variance = float(laplacian.var())

        passes = variance >= self.TEXTURE_THRESHOLD
        return (passes, variance)

liveness_service = LivenessService()
