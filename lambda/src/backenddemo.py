import os
import re
import time
from loguru import logger
import concurrent.futures
from dotenv import load_dotenv
from loguru import logger

import os
import uuid  
from dotenv import load_dotenv
import json

load_dotenv()

from groq import Groq
groq_client = Groq(
    api_key=os.environ.get("GROQ_API_KEY"),
)

SYSTEM_PROMPT_TEMPLATE_DE = """
Du bist Lisa, die Hotel Telefonassistentin. Du musst immer duzen. Wenn du eine Frage beantwortet hast, frag den User, ob Du ihm noch weiterhelfen kannst oder ob er noch andere Fragen hat. Wenn du nicht die passende Information hast, um die Frage zu beantworten, dann antworte nur "Mitarbeiter". Du kannst keine Reservierungen oder Buchungen machen, wenn der Anrufer eine Reservierung oder Buchung durchführen will, antworte nur "Mitarbeiter". Wenn sich der User verabschiedet oder keine weiteren Fragen hat oder das Gespräch beendet, nenne zuerst das Stichwort "Verabschiedung" und verabschiede dich freundlich.
Du antwortest auf Deutsch. Formuliere deine Antworten optimal für eine Sprachausgabe am Telefon als Fließtext ohne Sonderzeichen oder Aufzählungszeichen und nutze keine Emojis. Antworte kurz und auf den Punkt.
Du kennst nur folgende Informationen, um die User Frage zu beantworten:

"""

def read_file_content():
    try:
        with open('demo.txt', 'r') as file:
            content = file.read()
        return content
    except FileNotFoundError:
        print("Error: The file 'demo.txt' was not found.")
        return None
    except IOError:
        print("Error: There was an issue reading the file.")
        return None

def remove_special_characters_and_emojis(text):
    # Define a regex pattern to match all non-alphanumeric characters (except space)
    pattern = re.compile(r'[^A-Za-z0-9\s\.,\?äöüÄÖÜß]+')
    # Substitute the matched characters with an empty string
    cleaned_text = re.sub(pattern, '', text)
    return cleaned_text


def get_embedding(text, model="text-embedding-3-small"):
   return client.embeddings.create(input = text, model=model).data[0].embedding



def generate_conversation(user_query, history=None, hotel=None, language="de-DE"):
    # # get embeddings
    # user_query_embedding = get_embedding(user_query)
    # # print(user_query_embedding)
    # responses = index.query(queries=[user_query_embedding], top_k=2, include_metadata=True, filter={"location": hotel, "language":language})
    # # print(responses)
    # context = ""
    # for response in responses['results'][0]['matches']:
    #     text = response.metadata["text"].replace("\n", " ")
    #     context += text + "\n"
    # print(context)

    prompt = SYSTEM_PROMPT_TEMPLATE_DE + read_file_content()


    if history is None:
        history = []
        system = {
        "role": "system",
        "content": str(prompt)
        }
        history.append(system)  
    user = {
    "role": "user",
    "content": user_query
    }
    history.append(user)

    print(json.dumps(history, indent=4))
    print("chat_completion"*110)
    try:
        chat_completion = groq_client.chat.completions.create(
            messages=history,
            model="llama-3.1-70b-versatile"
            #model="llama3-70b-8192"
        )
        print("no error")
    except Exception as e:
        print("GPT Response Error: " + str(e))
        chat_completion = None
    

    try:
        if chat_completion is not None and len(chat_completion.choices[0].message.content) > 10:
            assistant = chat_completion.choices[0].message.content
        else:
            print("No response from GPT")
            assistant = "Mitarbeiter"
    except Exception as e:
        print("GPT Response Error: " + str(e))
        assistant = "Mitarbeiter"

    assistant = remove_special_characters_and_emojis(assistant)

    hangup = False
    if  "Verabschiedung" in assistant or "verabschiedung" in assistant:
        assistant = assistant.replace("Verabschiedung", "") 
        assistant = assistant.replace("verabschiedung", "")
        hangup = True  
    elif "Goodbye" in assistant or "goodbye" in assistant:
        assistant = assistant.replace("goodbye", "") 
        assistant = assistant.replace("Goodbye", "")
        hangup = True  

    if "Mitarbeiter" in assistant or "mitarbeiter" in assistant:
        assistant = "Hier kann ich leider nicht weiterhelfen, leite Sie aber gern an das Team weiter. Einen kleinen Augenblick bitte."
        hangup = True  


    dict = {"role": "assistant", "content": assistant}
    history.append(dict)
    
    response = {
        "gpt_response" : assistant,
        "history": history, 
        "phone_number": None,
        "hotel": hotel,
        "hangup": hangup
    }
    return response


if __name__ == "__main__":
    generate_conversation("Kann man bei euch parken?")
