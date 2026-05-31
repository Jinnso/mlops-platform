import os
import sys
import json
import tempfile
from pathlib import Path

import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
from sklearn.model_selection import train_test_split

import mlflow
import mlflow.xgboost

sys.path.insert(0, str(Path(__file__).parent.parent))

from src.data.download_data import download_taxi_data
from src.feature_engineering import preprocess_data, save_preprocessor


MLFLOW_TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000")
MLFLOW_S3_ENDPOINT = os.getenv("MLFLOW_S3_ENDPOINT_URL", "http://localhost:9000")
AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID", "minioadmin")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY", "minioadmin123")
EXPERIMENT_NAME = "taxi_fare_prediction"
MODEL_NAME = "taxi_fare_predictor"


def setup_mlflow():
    os.environ["AWS_ACCESS_KEY_ID"] = AWS_ACCESS_KEY
    os.environ["AWS_SECRET_ACCESS_KEY"] = AWS_SECRET_KEY
    os.environ["MLFLOW_S3_ENDPOINT_URL"] = MLFLOW_S3_ENDPOINT

    mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
    mlflow.set_experiment(EXPERIMENT_NAME)


def train(params: dict = None):
    if params is None:
        params = {
            "n_estimators": 200,
            "max_depth": 6,
            "learning_rate": 0.1,
            "subsample": 0.8,
            "colsample_bytree": 0.8,
            "objective": "reg:squarederror",
            "random_state": 42,
        }

    setup_mlflow()

    train_df, test_df = download_taxi_data()
    print(f"Data loaded: train={train_df.shape}, test={test_df.shape}")

    X_train, y_train, preprocessor = preprocess_data(train_df, fit=True)
    X_test, y_test = preprocess_data(test_df, preprocessor, fit=False)

    preprocessor_path = "data/processed/preprocessor.joblib"
    save_preprocessor(preprocessor, preprocessor_path)
    print(f"Preprocessor saved to {preprocessor_path}")

    with mlflow.start_run(run_name="xgboost-baseline") as run:
        mlflow.log_params(params)
        mlflow.log_metric("train_size", len(X_train))
        mlflow.log_metric("test_size", len(X_test))
        mlflow.log_param("num_features", X_train.shape[1])

        model = xgb.XGBRegressor(**params)
        model.fit(
            X_train, y_train,
            eval_set=[(X_test, y_test)],
            verbose=False,
        )

        y_pred = model.predict(X_test)

        rmse = np.sqrt(mean_squared_error(y_test, y_pred))
        mae = mean_absolute_error(y_test, y_pred)
        r2 = r2_score(y_test, y_pred)

        mlflow.log_metrics({
            "rmse": rmse,
            "mae": mae,
            "r2": r2,
        })

        print(f"RMSE: {rmse:.4f}, MAE: {mae:.4f}, R²: {r2:.4f}")

        mlflow.xgboost.log_model(
            model,
            artifact_path="model",
            registered_model_name=MODEL_NAME,
        )

        mlflow.log_artifact(preprocessor_path, artifact_path="preprocessor")

        feature_importance = model.get_booster().get_score(importance_type="gain")
        top_features = dict(sorted(feature_importance.items(), key=lambda x: x[1], reverse=True)[:10])
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump({
                "rmse": rmse,
                "mae": mae,
                "r2": r2,
                "params": params,
                "top_features": top_features,
            }, f, indent=2)
            mlflow.log_artifact(f.name, artifact_path="metrics")

        run_id = run.info.run_id
        print(f"MLflow Run ID: {run_id}")

        client = mlflow.tracking.MlflowClient()
        try:
            latest_versions = client.get_latest_versions(MODEL_NAME, stages=["None"])
            if latest_versions:
                client.transition_model_version_stage(
                    name=MODEL_NAME,
                    version=latest_versions[0].version,
                    stage="Staging",
                )
                print(f"Model {MODEL_NAME} version {latest_versions[0].version} promoted to Staging")
        except Exception as e:
            print(f"Model registration note: {e}")

        return run_id, rmse, mae, r2


if __name__ == "__main__":
    train()
