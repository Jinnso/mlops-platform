import os
import sys
import json
from pathlib import Path

import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score

import mlflow

sys.path.insert(0, str(Path(__file__).parent.parent))

from src.data.download_data import download_taxi_data
from src.feature_engineering import preprocess_data, load_preprocessor


MLFLOW_TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000")
MLFLOW_S3_ENDPOINT = os.getenv("MLFLOW_S3_ENDPOINT_URL", "http://localhost:9000")
AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID", "")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY", "")
MODEL_NAME = os.getenv("MODEL_NAME", "taxi_fare_predictor")


def evaluate_model(model_uri: str = None):
    os.environ["AWS_ACCESS_KEY_ID"] = AWS_ACCESS_KEY
    os.environ["AWS_SECRET_ACCESS_KEY"] = AWS_SECRET_KEY
    os.environ["MLFLOW_S3_ENDPOINT_URL"] = MLFLOW_S3_ENDPOINT

    mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)

    _, test_df = download_taxi_data()
    preprocessor = load_preprocessor("data/processed/preprocessor.joblib")
    X_test, y_test = preprocess_data(test_df, preprocessor, fit=False)

    if model_uri is None:
        client = mlflow.tracking.MlflowClient()
        versions = client.get_latest_versions(MODEL_NAME, stages=["Staging"])
        if versions:
            model_uri = f"models:/{MODEL_NAME}/Staging"
            print(f"Using model: {model_uri}")
        else:
            versions = client.get_latest_versions(MODEL_NAME)
            if versions:
                model_uri = f"models:/{MODEL_NAME}/{versions[0].version}"
                print(f"No Staging model, using version {versions[0].version}")
            else:
                raise RuntimeError(f"No registered model found for {MODEL_NAME}")

    model = mlflow.xgboost.load_model(model_uri)
    y_pred = model.predict(X_test)

    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    mae = mean_absolute_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)

    results = {
        "rmse": float(rmse),
        "mae": float(mae),
        "r2": float(r2),
        "model_uri": model_uri,
    }

    Path("data/processed").mkdir(parents=True, exist_ok=True)
    with open("data/processed/evaluation_results.json", "w") as f:
        json.dump(results, f, indent=2)

    print(f"Evaluation results: RMSE={rmse:.4f}, MAE={mae:.4f}, R²={r2:.4f}")

    thresholds = {"max_rmse": 5.0, "min_r2": 0.3}
    if rmse > thresholds["max_rmse"]:
        print(f"WARNING: RMSE {rmse:.4f} exceeds threshold {thresholds['max_rmse']}")
        sys.exit(1)
    if r2 < thresholds["min_r2"]:
        print(f"WARNING: R² {r2:.4f} below threshold {thresholds['min_r2']}")
        sys.exit(1)

    return results


if __name__ == "__main__":
    evaluate_model()
