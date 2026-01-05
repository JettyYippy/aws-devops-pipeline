# Use a lightweight Python image
FROM python:3.9-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the local code into the container
COPY . .

# Install the required library
RUN pip install flask

# Expose the port the app runs on
EXPOSE 5000

# Run the application
CMD ["python", "main.py"]
