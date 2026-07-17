from io import BytesIO
from typing import Optional
from uuid import UUID
import face_recognition
import numpy as np
from PIL import Image
from app.models import FaceEnrollment

class FaceRecognitionService:
    """Service class for face detection, embedding extraction, and face matching."""

    def detect_faces(self, image_bytes: bytes) -> list:
        """Detect face coordinates in the uploaded image."""
        image = self.load_image_from_bytes(image_bytes)
        locations = face_recognition.face_locations(image, model="hog")

        if len(locations) == 0:
            raise ValueError(
                "No face detected in the image. Please ensure the face is visible."
            )
        if len(locations) > 1:
            raise ValueError(
                "Multiple faces detected. Please upload an image with exactly one face."
            )
        return locations

    def extract_embedding(self, image_bytes: bytes) -> list[float]:
        """Extract the 128-dimensional face embedding vector."""
        image = self.load_image_from_bytes(image_bytes)
        locations = face_recognition.face_locations(image, model="hog")

        if len(locations) == 0:
            raise ValueError("No face detected in the image.")

        encodings = face_recognition.face_encodings(image, known_face_locations=locations)
        if len(encodings) == 0:
            raise ValueError("Failed to extract face embedding.")

        return encodings[0].tolist()

    def match_against_database(
        self,
        embedding: list[float],
        stored_enrollments: list[FaceEnrollment],
        threshold: float,
    ) -> tuple[Optional[UUID], float, str]:
        """Compare the face embedding against all enrolled profiles in the database."""
        if not stored_enrollments:
            return (None, 0.0, "no_enrolled_users")

        known_embeddings = np.array(
            [enrollment.face_embedding for enrollment in stored_enrollments],
            dtype=np.float64,
        )
        probe = np.array(embedding, dtype=np.float64)

        # Compute Euclidean distance using face_recognition distance calculator
        distances = face_recognition.face_distance(known_embeddings, probe)

        # Get the index of the closest match
        min_index = int(np.argmin(distances))
        min_distance = float(distances[min_index])

        # Convert distance to confidence score
        confidence = round(max(0.0, 1.0 - min_distance), 4)

        if min_distance <= threshold:
            matched_user_id = stored_enrollments[min_index].user_id
            return (matched_user_id, confidence, "match")
        else:
            return (None, confidence, "no_match")

    @staticmethod
    def load_image_from_bytes(image_bytes: bytes):
        """Convert image bytes to RGB format numpy array."""
        pil_image = Image.open(BytesIO(image_bytes)).convert("RGB")
        return np.array(pil_image)

face_service = FaceRecognitionService()
