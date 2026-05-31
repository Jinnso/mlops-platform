import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from src.data.download_data import download_taxi_data
from src.feature_engineering import preprocess_data


def test_data_download():
    train, test = download_taxi_data()
    assert len(train) > 0, "Train data is empty"
    assert len(test) > 0, "Test data is empty"
    assert "trip_duration_min" in train.columns
    assert "trip_duration_min" in test.columns
    assert train["trip_duration_min"].min() >= 0
    print("Data download test passed")


def test_feature_engineering():
    train, test = download_taxi_data()
    X_train, y_train, preprocessor = preprocess_data(train, fit=True)
    X_test, y_test = preprocess_data(test, preprocessor, fit=False)

    assert X_train.shape[0] == len(train)
    assert X_test.shape[0] == len(test)
    assert X_train.shape[1] >= 5, f"Expected at least 5 features, got {X_train.shape[1]}"
    assert len(y_train) == len(train)
    print(f"Feature engineering test passed: {X_train.shape[1]} features")


if __name__ == "__main__":
    test_data_download()
    test_feature_engineering()
    print("\nAll tests passed!")
