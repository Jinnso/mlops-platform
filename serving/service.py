import numpy as np
import bentoml
from pydantic import BaseModel, Field


@bentoml.service
class TaxiFarePredictor:

    def __init__(self):
        import joblib, os

        self.model = bentoml.xgboost.load_model("taxi_fare_predictor:latest")

        preprocessor_dir = os.path.join(os.path.dirname(__file__), "preprocessor")
        self.preprocessor = joblib.load(os.path.join(preprocessor_dir, "preprocessor.joblib"))

    @bentoml.api
    def predict(self, trip: "TripFeatures") -> dict:
        import pandas as pd

        df = pd.DataFrame([trip.model_dump()])
        cols = ["passenger_count", "trip_distance", "pickup_hour", "pickup_day", "pickup_month",
                "PULocationID", "DOLocationID", "rate_code"]

        X = df[cols].copy()

        features = self.preprocessor.transform(X)
        prediction = self.model.predict(features)

        return {
            "predicted_duration_min": round(float(prediction[0]), 2),
            "features": trip.model_dump(),
        }

    @bentoml.api
    def healthcheck(self) -> dict:
        return {"status": "healthy", "model": "taxi_fare_predictor"}


class TripFeatures(BaseModel):
    passenger_count: int = Field(default=1, ge=1, le=6)
    trip_distance: float = Field(default=2.0, ge=0.0, le=100.0)
    pickup_hour: int = Field(default=12, ge=0, le=23)
    pickup_day: int = Field(default=3, ge=0, le=6)
    pickup_month: int = Field(default=6, ge=1, le=12)
    PULocationID: int = Field(default=100, ge=1, le=265)
    DOLocationID: int = Field(default=200, ge=1, le=265)
    rate_code: int = Field(default=1, ge=1, le=6)
