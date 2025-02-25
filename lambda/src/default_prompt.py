DE_AI_PROMPT_TEMPLATE = """
Herzlich Willkommen bim Zipper Hotel. Ich bin Lisa, Deine K I Assistentin, wie kann ich dir helfen?
"""

EN_AI_PROMPT_TEMPLATE = """
Welcome to Mac Dreams Hotels. I'm Lisa, your AI assistant. How can I assist you?
"""

def get_ai_prompt_template(ai_prompt=None, language=None):
    ai_message = None
    if language == "en-US":
        ai_message = EN_AI_PROMPT_TEMPLATE
    else:
        ai_message = DE_AI_PROMPT_TEMPLATE
    return ai_message


