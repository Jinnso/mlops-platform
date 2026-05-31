import os
import numpy as np
import bentoml
import xgboost as xgb
from pydantic import BaseModel, Field


MODEL_NAME = os.getenv("MODEL_NAME", "taxi_fare_predictor")
MODEL_STAGE = os.getenv("MODEL_STAGE", "Production")

TAXI_RUNNER = bentoml.mlflow.get(f"{MODEL_NAME}:latest")

svc = bentoml.Service(
    name="taxi_fare_predictor",
    runners=[TAXI_RUNNER],
)


class TripFeatures(BaseModel):
    passenger_count: int = Field(default=1, ge=1, le=6)
    trip_distance: float = Field(default=2.0, ge=0.0, le=100.0)
    pickup_hour: int = Field(default=12, ge=0, le=23)
    pickup_day: int = Field(default=3, ge=0, le=6)
    pickup_month: int = Field(default=6, ge=1, le=12)
    PULocationID: int = Field(default=100, ge=1, le=265)
    DOLocationID: int = Field(default=200, ge=1, le=265)
    rate_code: int = Field(default=1, ge=1, le=6)


class BatchRequest(BaseModel):
    trips: list[TripFeatures]


class PredictionResponse(BaseModel):
    predictions: list[float]
    avg_duration_min: float
    count: int


@svc.api(input=bentoml.io.JSON(pydantic_model=TripFeatures), output=bentoml.io.JSON())
async def predict(trip: TripFeatures) -> dict:
    import pandas as pd

    df = pd.DataFrame([trip.model_dump()])
    numeric_cols = ["passenger_count", "trip_distance", "pickup_hour", "pickup_day", "pickup_month"]
    categorical_cols = ["PULocationID", "DOLocationID", "rate_code"]

    features = df[numeric_cols + categorical_cols].values
    prediction = await TAXI_RUNNER.predict.async_run(features)

    return {
        "predicted_duration_min": round(float(prediction[0]), 2),
        "features": trip.model_dump(),
    }


@svc.api(input=bentoml.io.JSON(pydantic_model=BatchRequest), output=bentoml.io.JSON())
async def predict_batch(batch: BatchRequest) -> PredictionResponse:
    import pandas as pd

    records = [t.model_dump() for t in batch.trips]
    df = pd.DataFrame(records)
    numeric_cols = ["passenger_count", "trip_distance", "pickup_hour", "pickup_day", "pickup_month"]
    categorical_cols = ["PULocationID", "DOLocationID", "rate_code"]

    features = df[numeric_cols + categorical_cols].values
    predictions = await TAXI_RUNNER.predict.async_run(features)

    pred_list = [round(float(p), 2) for p in predictions]
    return PredictionResponse(
        predictions=pred_list,
        avg_duration_min=round(float(np.mean(pred_list)), 2),
        count=len(pred_list),
    )


@svc.api(input=bentoml.io.Text(), output=bentoml.io.JSON())
async def healthcheck(_: str = "") -> dict:
    return {
        "status": "healthy",
        "model": MODEL_NAME,
        "stage": MODEL_STAGE,
    }
