import os
from apig_wsgi import make_lambda_handler
from src.server import app
import json

apig_wsgi_handler = make_lambda_handler(app)


def lambda_handler(event, context):
    # Check if this is a "keep-warm" invocation
    if event.get('source') == 'aws.events':
        print("This is a keep-warm invocation.")
        return {}

    print("incoming")
    print(json.dumps(event))
    print(event['rawPath'])
    response = apig_wsgi_handler(event, context)
    print("response")
    print(json.dumps(response))
    return response