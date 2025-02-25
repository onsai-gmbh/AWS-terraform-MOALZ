import json
from flask import Flask, request
from datetime import datetime, timedelta, UTC, timezone
import time
from src.default_prompt import get_ai_prompt_template
# from src.backend import generate_conversation
from src.backenddemo import generate_conversation
import uuid
import boto3
import string

import os
from dotenv import load_dotenv
import json
load_dotenv()
LANGUAGE = "de-DE" # default language
VOICE_NAME = "de-DE-SeraphinaMultilingualNeural" # default voice name
LOCAL_DYNAMO_DB_URL = os.getenv('LOCAL_DYNAMO_DB_URL')
DYNAMO_DB_TABLE = os.getenv('DYNAMO_DB_TABLE')
WHITE_LIST = ["+49911656544000", "0911656544000"]

app = Flask(__name__)


if LOCAL_DYNAMO_DB_URL:
    print("Using local DynamoDB ...")
    dynamodb = boto3.resource('dynamodb', endpoint_url=LOCAL_DYNAMO_DB_URL, region_name="localhost")
else:
    print("Using remote DynamoDB ...")
    print(DYNAMO_DB_TABLE)
    dynamodb = boto3.resource('dynamodb', region_name="eu-central-1")

table = dynamodb.Table(DYNAMO_DB_TABLE)

@app.route('/onsei', methods=['GET', 'POST', 'PUT', 'DELETE'])
def capture_request_test():
    print("Request received")
    return "Hello World!"

@app.route('/', methods=['GET', 'POST', 'PUT', 'DELETE'])
def capture_request():
    print("Request received")
    request_json = request.get_json()
    if  LOCAL_DYNAMO_DB_URL:
        print(json.dumps(request_json, indent=4, sort_keys=True))
    else:
        print(request_json)

    # Response
    activitiesURL = "/conversation/activities/" + request_json['conversation']
    refreshURL = "/conversation/refresh/" + request_json['conversation']
    disconnectURL = "/conversation/disconnect/" + request_json['conversation']

    response = {
        "activitiesURL": activitiesURL,
        "refreshURL": refreshURL,
        "disconnectURL": disconnectURL, 
        "expiresSeconds": 60
    }

    return json.dumps(response)

@app.route('/conversation/activities/<conversation_id>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def capture_activitie(conversation_id):
    print("Activitie received")
    start_time = time.time()  # get current time
    request_json = request.get_json()
    current_time = datetime.now(timezone.utc)
    timestamp = current_time.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

    if  LOCAL_DYNAMO_DB_URL:
        print(json.dumps(request_json, indent=4, sort_keys=True))
    else:
        print(request_json)

    try:
        caller = request_json['activities'][0]['parameters']['caller']
    except (IndexError, KeyError):
        caller = '000000000000'  # Ensure caller is a string for DynamoDB

    
    
    item = table.get_item(Key={'id': conversation_id}).get("Item")
    if item is None:
        print("New conversation")
        # Set language at the beginning of the conversation to German
        global LANGUAGE
        global VOICE_NAME
        LANGUAGE = "de-DE"
        VOICE_NAME = "de-DE-SeraphinaMultilingualNeural"
        try:
            get_id = request_json['activities'][0]['parameters']['callerDisplayName'].split(":")[1]
        except (IndexError, KeyError) as e:
            get_id = None
        print("Hotel ID: " + str(get_id))
    

        try:
            caller = request_json['activities'][0]['parameters']['caller']
        except (IndexError, KeyError) as e:
            caller = 000000000000

        print("Caller: " + str(caller))
        if caller in WHITE_LIST:
            white_list_transfer = {
                "id": str(uuid.uuid4()),
                "timestamp": timestamp,
                "type": "event",
                "name": "transfer",
                "activityParams": {
                    "transferTarget": "sip:816@mcdreams.3cx.eu"
                }
            }
            print(white_list_transfer)
            return json.dumps({"activities": [white_list_transfer]})
        
        # Check incoming number and add Hotel, if number is unknown, hotel is None
        if get_id == "W1-WS":
            hotel = "Wuppertal"
        elif get_id == "D1-WS":
            hotel = "Düsseldorf"
        elif get_id == "E1-WS":
            hotel = "Essen"
        elif get_id == "L1-WS":
            hotel = "Leipzig"
        elif get_id == "I1-WS":
            hotel = "Ingolstadt"
        elif get_id == "M2-WS":
            hotel = "München-Airport"
        elif get_id == "M1-WS":
            hotel = "München-Messe"
        elif get_id == "MG1-WS":
            hotel = "Mönchengladbach"
        else:
            hotel = None

        hotel = "Ingolstadt"

        print("Hotel Name: " + str(hotel))

        table.put_item(Item={'id': conversation_id, 'messages': "initialized", "system_history": [], "timestamp": timestamp, "hotel": hotel, "caller": caller})
        bot_response = get_ai_prompt_template() # get the German AI prompt

    elif item.get('messages') == 'initialized':
        user_query = request_json['activities'][0]['text']
        #user_query = request_json['activities'][0]['text'].strip(string.punctuation)
        hotel = item.get('hotel')
        # Get the language from the user's input
        if (len(user_query.split(" ")) > 2):
            LANGUAGE = "de-DE"
        print("USER: " + user_query)
        backend_respone = generate_conversation(user_query, hotel=hotel, language=LANGUAGE)
        print("backend_respone")
        print(backend_respone)
        table.update_item(
            Key={'id': conversation_id}, 
            UpdateExpression="set messages=:m, hotel=:h", 
            ExpressionAttributeValues={
                ':m': backend_respone['history'], 
                ':h': backend_respone['hotel']
            }
        )
        bot_response = backend_respone['gpt_response']
    else:   
        history = item.get('messages')
        hotel = item.get('hotel')
        system_history = item.get('system_history')
        system_history.append(history[0])
        user_query = request_json['activities'][0]['text']
        #user_query = request_json['activities'][0]['text'].strip(string.punctuation)
        print("USER: " + user_query)
        backend_respone = generate_conversation(user_query, history=history, hotel=hotel, language=LANGUAGE)
        table.update_item(
            Key={'id': conversation_id}, 
            UpdateExpression="set messages=:m, hotel=:h, system_history=:s", 
            ExpressionAttributeValues={
                ':m': backend_respone['history'], 
                ':h': backend_respone['hotel'],
                ':s': system_history
            }
        )       
        bot_response = backend_respone['gpt_response']

    activities = list()

    if LANGUAGE == "de-DE":
        VOICE_NAME = "de-DE-SeraphinaMultilingualNeural"
    elif LANGUAGE == "en-US":
        VOICE_NAME = "en-US-AmberNeural"

    activities.append({
    "id": str(uuid.uuid4()),
    "timestamp": timestamp,
    "language": LANGUAGE,
    "type": "message",
    "text": bot_response,
    "activityParams": {
        "language": LANGUAGE,
        "voiceName": VOICE_NAME
        }
    })

    try:
        if backend_respone.get('end_of_conversation'):
            activities.append({
                "id": str(uuid.uuid4()),
                "timestamp": timestamp,
                "type": "event",
                "name": "hangup"
            })
        phone_number = backend_respone.get('phone_number')
        print(phone_number)
        if phone_number is None:
            phone_number = "810"

        if backend_respone.get('phone_number'):
            activities.append({
                "id": str(uuid.uuid4()),
                "timestamp": timestamp,
                "type": "event",
                "name": "transfer",
                "activityParams": {
                    "transferTarget": "sip:" + phone_number + "@mcdreams.3cx.eu"
                }
            })

        if backend_respone.get('hangup'):
            activities.append({
                "id": str(uuid.uuid4()),
                "timestamp": timestamp,
                "type": "event",
                "name": "hangup"
            })

    except:
        pass
    
    print(activities)
    end_time = time.time()  # get current time after the API call
    print("Time taken for phonecall response call: " + str(end_time - start_time))
    system_response = {"activities": activities}
    
    # If the response time exceeds 3 seconds, send a warning to Sentry
    if (end_time - start_time) > 3:
        exceeding_time_message = "Phonetical resonse exceeds 3 seconds: " + str(end_time - start_time)
        print(exceeding_time_message)

    return json.dumps(system_response)


@app.route('/conversation/disconnect/<conversation_id>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def capture_disconnect(conversation_id):
    print("Disconnect received")
    request_json = request.get_json()
    if  LOCAL_DYNAMO_DB_URL:
        print(json.dumps(request_json, indent=4, sort_keys=True))
    else:
        print(request_json)

    # Response
    response = {}

    return json.dumps(response)

@app.route('/conversation/refresh/<conversation_id>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def capture_refresh(conversation_id):
    print("Refresh received")
    request_json = request.get_json()
    if  LOCAL_DYNAMO_DB_URL:
        print(json.dumps(request_json, indent=4, sort_keys=True))
    else:
        print(request_json)

    # Response
    response = { "expiresSeconds": 360}

    return json.dumps(response)



