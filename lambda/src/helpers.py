from datetime import datetime, time
import os
import json
import pytz

def time_checker():
    """Check if the service desk is open or closed."""
    # Define office hours
    office_start_hour = time(8, 0)
    office_end_hour = time(20, 0)
    office_days = {0, 1, 2, 3, 4}  # Monday to Friday, where Monday is 0 and Sunday is 6

    # Get current time and weekday in the Germany timezone
    germany_zone = pytz.timezone('Europe/Berlin')
    now = datetime.now(germany_zone)
    current_hour = now.time()
    current_weekday = now.weekday()

    # Check if current time is within office hours
    if current_weekday in office_days and office_start_hour <= current_hour < office_end_hour:
        return True
    else:
        return False
    
def no_hotel_info(results_with_confidence):
    unique = False
    for index, item in enumerate(results_with_confidence):
        if item[2] == True:
            results_with_confidence.pop(index)
            unique = True

    return results_with_confidence, unique

def get_text(scenario, language):
    """Get text based on scenario and language."""
    # Load JSON data
    with open('src/texts.json', 'r') as file:
        jsonData = json.load(file)

    # Access text based on scenario and language
    return jsonData[scenario][language]
