FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY --chown=10001:10001 app/ ./
RUN mkdir /data && chown 10001:10001 /data
USER 10001:10001
CMD ["python", "monitor.py"]
