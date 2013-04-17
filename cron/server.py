from bottle import route, run, template, request
import datetime as dt
datetime, timedelta, tzinfo = dt.datetime, dt.timedelta, dt.tzinfo
from sqlalchemy import create_engine, desc
from sqlalchemy.orm import sessionmaker
from sqlalchemy.sql import select

import sys
sys.path.append('./database/')
from sql_def import User, Phone, Reminder, SentMessage, ReceivedMessage

import json
import time, threading

engine = create_engine('postgresql://localhost/notify', echo=True)
# create a Session
Session = sessionmaker(bind=engine)

@route('/sms/status', method='POST')
def receive_sms_status():
   "TODO"
   from pprint import pprint
   print("SMS STATUS")
   pprint(request.POST)
   return ""

@route('/sms/receive', method='POST')
def receive_sms_page():
    sms = {"to": request.POST.get("To"),
        "from": request.POST.get("From"),
        "status": request.POST.get("SmsStatus"),
        "body": request.POST.get("Body"),
        "id": request.POST.get("SmsSid"),
        "apiversion": request.POST.get("ApiVersion"),
        "account": request.POST.get("AccountSid"),}
    sms["time_received"] = datetime.utcnow()
    receive_sms(sms)
    return "" #template("<b>Hello</b>!")

def receive_sms(sms):
    session = Session()
    # Create
    message = ReceivedMessage(account=sms["account"],
        twilio_id=sms["id"],
        from_=sms["from"],
        to=sms["to"],
        body=sms["body"],
        server_received=sms["time_received"],
        api_version=sms["apiversion"],
        twilio_status=sms["status"],
        )
    session.add(message)
    session.commit()
    # Process
    time_gotten = message.server_received
    # Find the last sent message before this one -- that's what this is in response to.
    query = session.query(SentMessage).filter(SentMessage.server_sent < message.server_received)
    in_response_to = query.order_by(desc(SentMessage.server_sent)).first()
    if in_response_to:
        message.in_response_to = in_response_to.id
    message.was_processed_after_received = True
    session.add(message)
    session.commit()

def schedule_message_to_send(body, to="+15135495690", from_="+15132015132", time=None, for_reminder_time=None):
    """time of None means 'now'"""
    if time is None:
        time = datetime.utcnow()
    session = Session()
    message = SentMessage(
        account = "AC84c3eee95bf50e49e7bbd0f1e42e530b",
        from_=from_,
        to=to,
        body=body,
        scheduled=time,
        sent_for_reminder_time=for_reminder_time)

def scheduled_messages(before_time=None):
    if before_time is None:
        before_time = datetime.utcnow()
        
    session = Session()
    s = session.query(SentMessage)
    s = s.filter(SentMessage.server_sent == None)
    s = s.filter(SentMessage.scheduled <= before_time)
    s = s.filter(SentMessage.cancelled == False)
    return session, s.all()
def send_all_scheduled_messages():
    session, messages = scheduled_messages()
    for message in messages:
        send_scheduled_message(message)
        session.add(message)
        session.commit()
def send_scheduled_message(message):
    # Make sure this message is still in allowable time.
    # if it's not, don't send it and instead refund the user a credit.
    reminder = message.sent_for_reminder_time.reminder
    if is_latest_reminder(reminder):
        print(message.body)
        message.body = reminder.message
    else:
        reminder.user.credit += 1
        message.cancelled = True
        return

    print(message.body)
    account = message.account
    token = {"AC84c3eee95bf50e49e7bbd0f1e42e530b":"a85c7381360cf4724b3862a87900c07c"}.get(account)
    
    server_sent_time = datetime.utcnow()
    url = "https://api.twilio.com/2010-04-01/Accounts/{account}/SMS/Messages.json".format(account=account)
    params = {"From":message.from_, "To":message.to, "Body":message.body, "ApplicationSid":"AP2a7be4e2e9b347d09de7fe35a8117804"}
    json_bytes = post(url, params, user=account, password=token)
    res = json.loads(json_bytes.decode("utf-8"))
    message.twilio_status = res["status"]
    if "message" in res and res["status"] == 400:
        message.cancelled = True
        reminder.user.credit += 1
        message.sent_for_reminder_time.reminder.error = res["message"]
        return
    from pprint import pprint
    pprint(res)
    
    session = Session()
    message.twilio_id = res["sid"]
    message.server_sent = server_sent_time
    message.api_version = res["api_version"]
    message.twilio_uri = res["uri"]

def post(url, params, user, password):
    assert(user and password or (not user and not password))
    from subprocess import check_output
    from urllib.parse import quote_plus
    curl_args  = ["-X", "POST"]
    curl_args += ["{}".format(url)]
    for key, value in params.items():
        curl_args += ["-d", "{key}={value}".format(key=key, value=quote_plus(value))]
    if user and password:
        curl_args += ["-u", "{user}:{password}".format(user=user, password=password)]
    
    return check_output(["curl"] + curl_args)

class Server():
    def __init__(self):
        self.started = False
    def start_server(self, **kwargs):
        if self.started:
            return self.started
        self.started = True # prevent double-start
        server = threading.Thread(target = lambda:run(host='0.0.0.0', **kwargs))
        #server.setDaemon(True)
        server.start()
        self.started=server
        return self.started
    def debug(self):
        self.start_server(debug=True, port=9002)
        while 1:
            self.periodic_tasks()
            time.sleep(5)
    def periodic_tasks(self):
        print("Looking for messages to schedulee...")
        schedule_messages()
        print("    Done.")
        print("Looking for messages to send...")
        send_all_scheduled_messages()
        print("    Done.")
        print()
        print()
        print()
        print("Sending emails.")
        send_emails()
        print("Done.")

def schedule_messages():
    '''find users without a scheduled messages and schedule them one'''
    # Let's be realistic -- make this more efficient once we need to.
    session = Session()
    total_queued_messages = 0
    for user in session.query(User):
        times = []
        for reminder in user.reminders:
            if is_latest_reminder(reminder): #latest version of the reminder
              for time in reminder.times:
                  times.append(time)
                  q = session.query(SentMessage)
                  q = q.filter(SentMessage.sent_for_reminder_time_id == time.id)
                  q = q.filter(SentMessage.server_sent == None)
                  q = q.filter(SentMessage.cancelled == False)
                  queued_messages = q.count()
                  if queued_messages == 0:
                    schedule_reminder_time_for_user(time, user)
                  print("QUEUED MESSAGES: {}".format(queued_messages))
                  total_queued_messages += queued_messages
    print("TOTAL_QUEUED MESSAGES: {}".format(total_queued_messages))
    session.commit()
 
def is_latest_reminder(reminder):
    if reminder.parent:
      sibs = reminder.parent.children
      max_version = reminder.version
      for sib in sibs:
          if sib.version > max_version:
            max_version = sib.version
      return max_version == reminder.version
    else:
      return len(reminder.children)==0

def next_scheduled_time(start_time, end_time, days, frequency_per_day, current_datetime, user_timezone):
    import random
    days = days_as_array(days)
    if days == [0,0,0,0,0,0,0]:
       return None
    print(days)
    user_timezone_delta = timedelta(seconds=user_timezone)
    daily_duration = end_time - start_time
    if daily_duration <= 0:
        return None
    avg_interval = daily_duration / frequency_per_day
    delay_interval = random.expovariate(1) * avg_interval

    print("Current (UTC): " + str(current_datetime))
    current_datetime += user_timezone_delta
    print("Current (user): " + str(current_datetime))
    # schedule at the earliest available opportunity if we're outside valid times
    current_seconds = current_datetime.second + current_datetime.minute * 60 + current_datetime.hour * 3600
    if days[current_datetime.weekday()] == 0 or not (start_time < current_seconds < end_time):
        # roll the time forward to start_time
        current_datetime += timedelta(seconds=(start_time - current_seconds))
        if start_time < current_seconds: # we rolled back a bit; go forwards again
            current_datetime += timedelta(days=1)
        current_seconds = current_datetime.second + current_datetime.minute * 60 + current_datetime.hour * 3600
        assert(current_seconds == start_time)
    while days[current_datetime.weekday()] == 0:
        current_datetime += timedelta(days=1)
    current_date = datetime.combine(current_datetime.date(), dt.time())
    print(end_time)
    print("Adjusted (user): " + str(datetime.combine(current_datetime.date(), dt.time())+timedelta(seconds=current_seconds)))
    
    import math
    delay_days = math.ceil(float(max(0, current_seconds + delay_interval - end_time)) / daily_duration)
    print(delay_days)
    post_delay_seconds = ((current_seconds + delay_interval - start_time) % daily_duration) + start_time
    print(delay_interval)
    print(daily_duration)
    print(start_time)
    print(current_seconds)
    print(post_delay_seconds)
    if post_delay_seconds < 0:
        print('egads!')
    #import pdb;pdb.set_trace()

    post_delay_date = current_date
    while delay_days > 0:
        print("subtracting " + str(delay_days) + "st/nd/th day: " + str(post_delay_date))
        delay_days -= 1
        post_delay_date += timedelta(days=1)
        while days[post_delay_date.weekday()] == 0:
            post_delay_date +=timedelta(days=1)

    post_delay_datetime = datetime.combine(post_delay_date.date(), dt.time()) + timedelta(seconds=post_delay_seconds)
    print("Final (user): " + str(post_delay_datetime))
    post_delay_datetime -= user_timezone_delta

    print("Final (UTC): " + str(post_delay_datetime))
    return post_delay_datetime
    
def days_as_array(d):
    #days = Column(Integer) # flag field where    1:sun 2:mon 4:tue 8:wed 16:thur 32:fri 64:sat
    # datetime.weekday(): monday is 0, sunday is 6
    # output of this function is an array a, such that a[0] is monday, a[6] is sunday
    return [ d&2, d&4, d&8, d&16, d&32, d&64, d&1 ] 

def schedule_reminder_time_for_user(reminder_time, user):
    if user.credit <= 0:
        print("Nope, not enough credits")
        return
    else:
        user.credit -= 1
  
    scheduled_time = next_scheduled_time(reminder_time.start, reminder_time.end, reminder_time.days, reminder_time.frequency, datetime.utcnow(), user.timezone.offset)
    if scheduled_time is None:
    	return None
    
    print(scheduled_time)
    print(reminder_time.reminder.message)
    schedule_message_to_send(
        body=reminder_time.reminder.message,
        to=reminder_time.reminder.phone.number,
        time=scheduled_time,
        for_reminder_time=reminder_time)

def timedelta_times(td, c):
    return timedelta(seconds=td.total_seconds()*c)
    

def send_emails():
    # see if any users should be emailed about their responses (nightly?)
    pass

if __name__ == '__main__':
    print("Starting server.")
    server = Server()
    server.debug()
