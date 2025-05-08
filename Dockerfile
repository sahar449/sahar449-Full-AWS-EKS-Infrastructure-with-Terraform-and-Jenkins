# Use a specific Python image as the base image
FROM python:3.9-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the application code into the container
COPY app.py /app

# Install Flask and stress tool
RUN pip install flask && \
    apt-get update && \
    apt-get install -y stress

# Start the application
CMD ["python", "app.py"]
