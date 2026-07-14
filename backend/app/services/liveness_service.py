"""
Liveness-detection service to distinguish real faces from spoofing attacks
(printed photos, screen replays, static masks).

If biometrics dependencies (OpenCV, SciPy, face_recognition) are missing,
gracefully falls back to mock liveness checks.
"""

from io import BytesIO
from typing import Optional

try:
    import cv2
    import face_recognition
    import numpy as np
    from scipy.spatial.distance import euclidean
    HAS_LIVENESS_DEPS = True
except ImportError:
    HAS_LIVENESS_DEPS = False
    cv2 = None
    face_recognition = None
    np = None
    euclidean = None

from PIL import Image


class LivenessService:
    """Stateless service wrapping anti-spoofing heuristics."""

    # Laplacian-variance threshold.
    TEXTURE_THRESHOLD: float = 100.0

    # Minimum landmark-position standard deviation (pixels) expected.
    MOVEMENT_STD_THRESHOLD: float = 0.5

    # ── Public API ───────────────────────────────────────────────────────

    def check_liveness(self, frames: list[bytes]) -> tuple[bool, str]:
        """
        Run the full liveness pipeline on one or more frames.

        Args:
            frames: List of JPEG/PNG image byte-strings captured from the client camera.

        Returns:
            ``(is_live, reason)`` – *reason* explains the decision.
        """
        if not frames:
            return (False, "no_frames_provided")

        if not HAS_LIVENESS_DEPS:
            print("[INFO] Liveness check: Mock mode (passed)")
            return (True, "liveness_passed_mock")

        # ── Texture check on the primary (first) frame ──
        texture_ok, variance = self._check_texture(frames[0])
        if not texture_ok:
            return (
                False,
                f"texture_fail:laplacian_var={variance:.1f}",
            )

        # ── Multi-frame consistency (only when >1 frame provided) ──
        if len(frames) > 1:
            movement_ok, movement_reason = self._check_multi_frame_consistency(frames)
            if not movement_ok:
                return (False, movement_reason)

        return (True, "liveness_passed")

    # ── Texture Analysis ─────────────────────────────────────────────────

    def _check_texture(self, image_bytes: bytes) -> tuple[bool, float]:
        """
        Compute the Laplacian variance of the grayscale image.

        A low variance indicates the image lacks high-frequency detail.
        """
        if not HAS_LIVENESS_DEPS:
            return (True, 150.0)

        pil_image = Image.open(BytesIO(image_bytes)).convert("RGB")
        cv_image = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(cv_image, cv2.COLOR_BGR2GRAY)

        laplacian = cv2.Laplacian(gray, cv2.CV_64F)
        variance = float(laplacian.var())

        passes = variance >= self.TEXTURE_THRESHOLD
        return (passes, variance)

    # ── Multi-Frame Consistency ──────────────────────────────────────────

    def _check_multi_frame_consistency(
        self, frames: list[bytes]
    ) -> tuple[bool, str]:
        """
        Compare face-landmark positions across *frames* to detect natural micro-movements.
        """
        if not HAS_LIVENESS_DEPS:
            return (True, "movement_ok_mock")

        all_nose_tips: list[tuple[int, int]] = []

        for frame_bytes in frames:
            pil_image = Image.open(BytesIO(frame_bytes)).convert("RGB")
            image_array = np.array(pil_image)
            landmarks_list = face_recognition.face_landmarks(image_array)

            if not landmarks_list:
                # Skip frames where no face is found
                continue

            # Use the nose-tip landmark set as a representative point
            nose_bridge = landmarks_list[0].get("nose_bridge", [])
            if nose_bridge:
                # Take the last point of the nose bridge (tip approximation)
                all_nose_tips.append(nose_bridge[-1])

        if len(all_nose_tips) < 2:
            return (
                False,
                "insufficient_landmark_frames",
            )

        # Compute standard deviation of x and y coordinates
        coords = np.array(all_nose_tips, dtype=np.float64)
        std_x = float(np.std(coords[:, 0]))
        std_y = float(np.std(coords[:, 1]))
        combined_std = (std_x + std_y) / 2.0

        if combined_std < self.MOVEMENT_STD_THRESHOLD:
            return (
                False,
                f"no_movement_detected:std={combined_std:.3f}",
            )

        return (True, "movement_ok")

    # ── Eye Aspect Ratio (EAR) ───────────────────────────────────────────

    @staticmethod
    def _compute_ear(eye_landmarks: list[tuple[int, int]]) -> float:
        """
        Compute the Eye Aspect Ratio (EAR) from 6 landmark points.
        """
        if not HAS_LIVENESS_DEPS:
            return 0.25

        p1, p2, p3, p4, p5, p6 = eye_landmarks
        vertical_a = euclidean(p2, p6)
        vertical_b = euclidean(p3, p5)
        horizontal = euclidean(p1, p4)
        if horizontal == 0:
            return 0.0
        return (vertical_a + vertical_b) / (2.0 * horizontal)


# Module-level singleton
liveness_service = LivenessService()
