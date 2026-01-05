from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return """
    <html>
    <head><title>Success!</title></head>
    <body style="background-color: #f0f8ff; font-family: sans-serif; text-align: center; padding-top: 50px;">
        <h1 style="color: #2e8b57;">Success! Your AWS DevOps Pipeline is Live!</h1>
        <p>Managed by Jenkins & Kubernetes (K3s).</p>
        <p>Environment: <b>Production</b></p>
    </body>
    </html>
    """

if __name__ == "__main__":
    # The app must run on 0.0.0.0 to be accessible outside the container
    app.run(host='0.0.0.0', port=5000)
