# Headless LiveKit participants for the M3 call acceptance test (calltest/run.py).
FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 libglib2.0-0 libgl1 && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir "livekit==1.0.*"
WORKDIR /calltest
COPY run.py .
ENTRYPOINT ["python", "run.py"]
