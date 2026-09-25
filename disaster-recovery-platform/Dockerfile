FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=10001:10001 app/ ./
ARG SERVICE=app
ENV SERVICE=$SERVICE
USER 10001:10001
EXPOSE 8080
CMD ["python", "runtime.py"]
