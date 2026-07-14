"""
Face-recognition pipeline: detection, embedding extraction, and matching.

Uses dlib (via the ``face_recognition`` library) to produce 128-dimensional
face descriptors and compares them with Euclidean distance.
If libraries are missing, gracefully falls back to mock/simulated biometrics.
"""

from io import BytesIO
import hashlib
import random
from typing import Optional
from uuid import UUID

try:
    import face_recognition
    import numpy as np
    HAS_FACE_RECOGNITION = True
except ImportError:
    HAS_FACE_RECOGNITION = False
    np = None

from PIL import Image

from app.models import FaceEnrollment


class FaceRecognitionService:
    """Stateless service wrapping face-recognition operations."""

    # ── Detection ────────────────────────────────────────────────────────

    def detect_faces(self, image_bytes: bytes) -> list:
        """
        Detect face bounding boxes in *image_bytes*.

        Returns:
            A list of ``(top, right, bottom, left)`` tuples.

        Raises:
            ValueError: If zero or more than one face is found.
        """
        if HAS_FACE_RECOGNITION:
            image = self.load_image_from_bytes(image_bytes)
            locations = face_recognition.face_locations(image, model="hog")
        else:
            # Mock mode: check if it's a valid image, then return a mock bounding box
            try:
                Image.open(BytesIO(image_bytes))
                locations = [(0, 100, 100, 0)]  # Mock face box
                print("[INFO] Mock Face Detection: 1 face detected")
            except Exception as e:
                raise ValueError(f"Invalid image format: {e}")

        if len(locations) == 0:
            raise ValueError(
                "No face detected in the image. "
                "Please ensure the photo is well-lit and the face is clearly visible."
            )
        if len(locations) > 1:
            raise ValueError(
                f"Multiple faces ({len(locations)}) detected. "
                "Please submit a photo containing exactly one face."
            )
        return locations

    # ── Embedding Extraction ─────────────────────────────────────────────

    def extract_embedding(self, image_bytes: bytes) -> list[float]:
        """
        Extract a 128-dimensional face embedding from *image_bytes*.

        Raises:
            ValueError: If face detection or encoding fails.
        """
        if HAS_FACE_RECOGNITION:
            image = self.load_image_from_bytes(image_bytes)
            locations = face_recognition.face_locations(image, model="hog")

            if len(locations) == 0:
                raise ValueError("No face detected – cannot extract embedding.")

            encodings = face_recognition.face_encodings(image, known_face_locations=locations)
            if len(encodings) == 0:
                raise ValueError("Failed to compute face encoding.")

            return encodings[0].tolist()
        else:
            # Mock mode: Generate a deterministic embedding based on image content
            try:
                Image.open(BytesIO(image_bytes))
                hasher = hashlib.sha256(image_bytes)
                seed = int(hasher.hexdigest(), 16) % (2**32)
                rng = random.Random(seed)
                # Generate 128 floats
                mock_embedding = [rng.uniform(-0.1, 0.1) for _ in range(128)]
                print("[INFO] Mock Face Embedding: generated deterministic 128-d vector")
                return mock_embedding
            except Exception as e:
                raise ValueError(f"No face detected – cannot extract embedding: {e}")

    # ── Matching ─────────────────────────────────────────────────────────

    def match_against_database(
        self,
        embedding: list[float],
        stored_enrollments: list[FaceEnrollment],
        threshold: float,
    ) -> tuple[Optional[UUID], float, str]:
        """
        Compare *embedding* against every stored enrollment and return the
        best match (if any).

        Args:
            embedding: 128-d face descriptor of the probe image.
            stored_enrollments: All ``FaceEnrollment`` records from the DB.
            threshold: Maximum Euclidean distance for a positive match.

        Returns:
            A 3-tuple ``(matched_user_id | None, confidence, reason)``.
        """
        if not stored_enrollments:
            return (None, 0.0, "no_enrolled_users")

        if HAS_FACE_RECOGNITION and np is not None:
            # Build a (N, 128) array of stored embeddings
            known_embeddings = np.array(
                [enrollment.face_embedding for enrollment in stored_enrollments],
                dtype=np.float64,
            )
            probe = np.array(embedding, dtype=np.float64)

            # Compute Euclidean distances to every stored embedding
            distances = face_recognition.face_distance(known_embeddings, probe)

            # Find closest match
            min_index = int(np.argmin(distances))
            min_distance = float(distances[min_index])
        else:
            # Pure Python fallback for distance calculation
            min_distance = float('inf')
            min_index = -1
            
            for idx, enrollment in enumerate(stored_enrollments):
                # Calculate Euclidean distance manually
                db_emb = enrollment.face_embedding
                # Handle cases where db_emb is stored as list or numpy array
                if hasattr(db_emb, "tolist"):
                    db_emb = db_emb.tolist()
                
                dist = sum((x - y) ** 2 for x, y in zip(db_emb, embedding)) ** 0.5
                if dist < min_distance:
                    min_distance = dist
                    min_index = idx

        # Confidence is the inverse of distance (clamped to [0, 1])
        confidence = round(max(0.0, 1.0 - min_distance), 4)

        if min_distance <= threshold:
            matched_user_id = stored_enrollments[min_index].user_id
            return (matched_user_id, confidence, "match")
        else:
            return (None, confidence, "no_match")

    # ── Image Loading ────────────────────────────────────────────────────

    @staticmethod
    def load_image_from_bytes(image_bytes: bytes):
        """Convert raw image bytes to an RGB numpy array for face_recognition."""
        pil_image = Image.open(BytesIO(image_bytes)).convert("RGB")
        if HAS_FACE_RECOGNITION and np is not None:
            return np.array(pil_image)
        return pil_image


# Module-level singleton
face_service = FaceRecognitionService()
