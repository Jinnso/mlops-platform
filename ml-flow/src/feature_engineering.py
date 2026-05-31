import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
import joblib


NUMERIC_FEATURES = [
    "passenger_count",
    "trip_distance",
    "pickup_hour",
    "pickup_day",
    "pickup_month",
]

CATEGORICAL_FEATURES = [
    "PULocationID",
    "DOLocationID",
    "rate_code",
]


def build_preprocessor() -> ColumnTransformer:
    numeric_transformer = Pipeline([
        ("scaler", StandardScaler()),
    ])

    categorical_transformer = Pipeline([
        ("onehot", OneHotEncoder(
            handle_unknown="ignore",
            max_categories=50,
            sparse_output=False,
        )),
    ])

    preprocessor = ColumnTransformer(
        transformers=[
            ("num", numeric_transformer, NUMERIC_FEATURES),
            ("cat", categorical_transformer, CATEGORICAL_FEATURES),
        ],
        remainder="drop",
    )
    return preprocessor


def preprocess_data(df: pd.DataFrame, preprocessor: ColumnTransformer = None, fit: bool = True):
    features = NUMERIC_FEATURES + CATEGORICAL_FEATURES
    X = df[features].copy()
    y = df["trip_duration_min"].values

    X[NUMERIC_FEATURES] = X[NUMERIC_FEATURES].fillna(X[NUMERIC_FEATURES].median())
    X[CATEGORICAL_FEATURES] = X[CATEGORICAL_FEATURES].fillna(0).astype(int)

    if preprocessor is None:
        preprocessor = build_preprocessor()

    if fit:
        X_processed = preprocessor.fit_transform(X)
        return X_processed, y, preprocessor
    else:
        X_processed = preprocessor.transform(X)
        return X_processed, y


def save_preprocessor(preprocessor: ColumnTransformer, path: str):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(preprocessor, path)


def load_preprocessor(path: str) -> ColumnTransformer:
    return joblib.load(path)
