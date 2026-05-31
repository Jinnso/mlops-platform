import sys
import json
from pathlib import Path
from datetime import datetime

import pandas as pd
import numpy as np
from evidently import Report
from evidently.presets import DataDriftPreset, DataSummaryPreset


REPORT_DIR = Path("/app/reports")
REPORT_DIR.mkdir(parents=True, exist_ok=True)


def generate_data():
    np.random.seed(42)
    n_samples = 5000

    data = pd.DataFrame({
        "passenger_count": np.random.randint(1, 7, n_samples),
        "trip_distance": np.random.exponential(3, n_samples).clip(0.1, 50),
        "pickup_hour": np.random.randint(0, 24, n_samples),
        "pickup_day": np.random.randint(0, 7, n_samples),
        "pickup_month": np.random.randint(1, 13, n_samples),
        "PULocationID": np.random.randint(1, 266, n_samples),
        "DOLocationID": np.random.randint(1, 266, n_samples),
        "rate_code": np.random.choice([1, 2, 3, 4, 5, 6], n_samples, p=[0.7, 0.1, 0.05, 0.05, 0.05, 0.05]),
    })
    data["trip_duration_min"] = (
        2.0 + 0.5 * data["trip_distance"] + 0.3 * data["passenger_count"]
        + 0.1 * (data["pickup_hour"] % 12) + 0.05 * data["pickup_day"]
        + np.random.normal(0, 1.5, n_samples)
    ).clip(1, 120)

    ref = data.iloc[:4000]
    cur = data.iloc[4000:]
    return ref, cur


def run_monitoring():
    reference_data, current_data = generate_data()

    report = Report(metrics=[
        DataDriftPreset(),
        DataSummaryPreset(),
    ])

    snapshot = report.run(reference_data=reference_data, current_data=current_data)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    report_path = REPORT_DIR / f"monitoring_report_{timestamp}.html"
    snapshot.save_html(str(report_path))

    summary_path = REPORT_DIR / f"summary_{timestamp}.json"
    snapshot.save_json(str(summary_path))

    print(f"Report saved to {report_path}")
    print(f"Summary saved to {summary_path}")
    print("Monitoring complete")
    return 0


if __name__ == "__main__":
    sys.exit(run_monitoring())
