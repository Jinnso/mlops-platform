import os
import sys
import json
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score

import mlflow

sys.path.insert(0, str(Path(__file__).parent.parent))

from src.data.download_data import download_taxi_data
from src.feature_engineering import preprocess_data, load_preprocessor
from src.train import setup_mlflow


MLFLOW_TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000")
AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID", "minioadmin")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY", "minioadmin123")
MODEL_NAME = os.getenv("MODEL_NAME", "taxi_fare_predictor")
RETRAIN_THRESHOLD = float(os.getenv("RETRAIN_RMSE_THRESHOLD", "0.05"))


def check_drift_and_retrain():
    os.environ["AWS_ACCESS_KEY_ID"] = AWS_ACCESS_KEY
    os.environ["AWS_SECRET_ACCESS_KEY"] = AWS_SECRET_KEY
    os.environ["MLFLOW_S3_ENDPOINT_URL"] = os.getenv(
        "MLFLOW_S3_ENDPOINT_URL", "http://localhost:9000"
    )

    mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
    client = mlflow.tracking.MlflowClient()

    print("Checking for production model...")
    prod_versions = client.get_latest_versions(MODEL_NAME, stages=["Production"])

    if prod_versions:
        print(f"Production model: version {prod_versions[0].version}")
        prod_run = client.get_run(prod_versions[0].run_id)
        prod_rmse = prod_run.data.metrics.get("rmse", float("inf"))
        prod_r2 = prod_run.data.metrics.get("r2", float("-inf"))
        print(f"Production metrics: RMSE={prod_rmse:.4f}, R²={prod_r2:.4f}")
    else:
        print("No production model found. Promoting latest staging model...")
        staging_versions = client.get_latest_versions(MODEL_NAME, stages=["Staging"])
        if staging_versions:
            client.transition_model_version_stage(
                name=MODEL_NAME,
                version=staging_versions[0].version,
                stage="Production",
            )
            print(f"Model {MODEL_NAME} v{staging_versions[0].version} promoted to Production")
        else:
            versions = client.get_latest_versions(MODEL_NAME)
            if versions:
                client.transition_model_version_stage(
                    name=MODEL_NAME,
                    version=versions[0].version,
                    stage="Production",
                )
                print(f"Model {MODEL_NAME} v{versions[0].version} promoted to Production")
        return True

    staging_versions = client.get_latest_versions(MODEL_NAME, stages=["Staging"])
    if not staging_versions:
        print("No staging model to compare. Triggering re-training...")
        return False

    staging_run = client.get_run(staging_versions[0].run_id)
    staging_rmse = staging_run.data.metrics.get("rmse", float("inf"))
    staging_r2 = staging_run.data.metrics.get("r2", float("-inf"))

    improvement = prod_rmse - staging_rmse
    r2_improvement = staging_r2 - prod_r2

    print(f"Staging RMSE: {staging_rmse:.4f} (diff: {improvement:+.4f})")
    print(f"Staging R²: {staging_r2:.4f} (diff: {r2_improvement:+.4f})")

    if improvement > RETRAIN_THRESHOLD:
        print("Promoting staging model to production...")
        client.transition_model_version_stage(
            name=MODEL_NAME,
            version=staging_versions[0].version,
            stage="Production",
        )
        print(f"Model {MODEL_NAME} v{staging_versions[0].version} promoted to Production")
        return True
    else:
        print(f"No significant improvement. Staging RMSE {staging_rmse:.4f} vs Production {prod_rmse:.4f}")
        return False


if __name__ == "__main__":
    result = check_drift_and_retrain()
    if result:
        print("Model updated successfully")
    else:
        print("Model not updated - current model is still optimal")
