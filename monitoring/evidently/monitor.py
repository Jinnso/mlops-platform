import os
import sys
import json
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset, RegressionPreset, DataQualityPreset
from evidently.metrics import RegressionQualityMetric, DatasetDriftMetric

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from ml_flow.src.data.download_data import download_taxi_data

REPORT_DIR = Path(__file__).parent / "reports"
REPORT_DIR.mkdir(parents=True, exist_ok=True)


def run_monitoring():
    train_df, test_df = download_taxi_data()

    reference_data = train_df.sample(n=min(5000, len(train_df)), random_state=42)
    current_data = test_df.sample(n=min(5000, len(test_df)), random_state=42)

    drift_report = Report(metrics=[
        DataDriftPreset(),
        DataQualityPreset(),
        RegressionPreset(),
    ])

    drift_report.run(
        reference_data=reference_data,
        current_data=current_data,
        column_mapping=None,
    )

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_path = REPORT_DIR / f"monitoring_report_{timestamp}.html"
    drift_report.save_html(str(report_path))

    results = drift_report.as_dict()
    summary = {
        "timestamp": timestamp,
        "data_drift_detected": results.get("metrics", [{}])[0].get("result", {}).get("dataset_drift", False),
        "number_of_drifted_columns": results.get("metrics", [{}])[0].get("result", {}).get("number_of_drifted_columns", 0),
        "number_of_columns": results.get("metrics", [{}])[0].get("result", {}).get("number_of_columns", 0),
    }

    summary_path = REPORT_DIR / f"summary_{timestamp}.json"
    with open(summary_path, "w") as f:
        json.dump(summary, f, indent=2)

    print(f"Monitoring report saved to {report_path}")
    print(f"Summary: {json.dumps(summary, indent=2)}")

    if summary["data_drift_detected"]:
        print("DRIFT DETECTED - Consider retraining the model")
        return 1

    print("No significant drift detected")
    return 0


if __name__ == "__main__":
    sys.exit(run_monitoring())
