FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    bentoml>=1.4.0 \
    xgboost>=2.1.0 \
    numpy>=2.0.0 \
    pandas>=2.2.0 \
    scikit-learn>=1.6.0 \
    mlflow>=2.19.0 \
    boto3>=1.36.0

COPY service.py .

ENV MLFLOW_TRACKING_URI=http://mlflow.mlops.svc.cluster.local:5000
ENV AWS_DEFAULT_REGION=us-east-1
ENV MLFLOW_S3_ENDPOINT_URL=http://minio.storage.svc.cluster.local:9000

EXPOSE 3000

CMD ["bentoml", "serve", "service:svc", "--host", "0.0.0.0", "--port", "3000"]
