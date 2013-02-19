from bottle import route, run, template, request
import datetime as dt
datetime, timedelta = dt.datetime, dt.timedelta
from sqlalchemy import create_engine, desc
from sqlalchemy.orm import sessionmaker
from sqlalchemy.sql import select

import sys
sys.path.append('./../database/')
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
    #TODO: Make sure this message is still in allowable time.
    # if it's not, don't send it and instead refund the user a credit.
    print(message.body)
    account = message.account
    token = {"AC84c3eee95bf50e49e7bbd0f1e42e530b":"a85c7381360cf4724b3862a87900c07c"}.get(account)
    
    server_sent_time = datetime.utcnow()
    url = "https://api.twilio.com/2010-04-01/Accounts/{account}/SMS/Messages.json".format(account=account)
    params = {"From":message.from_, "To":message.to, "Body":message.body, "ApplicationSid":"AP2a7be4e2e9b347d09de7fe35a8117804"}
    json_bytes = post(url, params, user=account, password=token)
    res = json.loads(json_bytes.decode("utf-8"))
    from pprint import pprint
    pprint(res)
    
    session = Session()
    assert(res["account_sid"]==account)
    assert(res["from"]==message.from_)
    assert(res["to"]==message.to)
    assert(res["body"]==message.body)
    message.twilio_id = res["sid"]
    message.server_sent = server_sent_time
    message.twilio_status = res["status"]
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
        self.start_server(debug=True, port=8080)
        while 1:
            self.periodic_tasks()
            time.sleep(5)
    def periodic_tasks(self):
        print("Looking for messages to schedule...")
        schedule_messages()
        print("    Done.")
        print("Looking for messages to send...")
        send_all_scheduled_messages()
        print("    Done.")
        send_emails()

def schedule_messages():
    '''find users without a scheduled messages and schedule them one'''
    # Let's be realistic -- make this more efficient once we need to.
    session = Session()
    for user in session.query(User):
        times = []  
        for reminder in user.reminders:
            if len(reminder.children) == 0: #latest version of the reminder
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
            else: #old versions of reminders
              for time in reminder.times:
                  q = session.query(SentMessage)
                  q = q.filter(SentMessage.sent_for_reminder_time_id == time.id)
                  q = q.filter(SentMessage.server_sent == None)
                  q = q.filter(SentMessage.cancelled == False)
                  for msg in q.all():
                    msg.cancelled = True
                    user.credit += 1
    session.commit()

def next_scheduled_time(start_time, end_time, days, frequency_per_day, current_datetime):
    #import pdb;pdb.set_trace()
    import random
    days = days_as_array(days)
    daily_duration = end_time - start_time
    avg_interval = daily_duration / frequency_per_day
    delay_interval = random.expovariate(1) * avg_interval

    current_seconds = current_datetime.second + current_datetime.minute * 60 + current_datetime.hour * 3600
    current_date = datetime.combine(current_datetime.date(), dt.time())
    # schedule at the earliest available opportunity if we're outside valid times
    while not days[current_date.weekday()]: # 
        current_date += timedelta(days=1)
        current_seconds = start_time 
    if not (start_time <= current_seconds <= end_time):
        current_seconds = start_time 

    delay_days = (current_seconds + delay_interval) // daily_duration
    post_delay_seconds = ((current_seconds + delay_interval - start_time) % daily_duration) + start_time

    post_delay_date = current_date
    while delay_days > 0:
        delay_days -= 1
        post_delay_date += timedelta(days=1)
        while not days[post_delay_date.weekday()]:
            post_delay_date +=timedelta(days=1)

    post_delay_datetime = datetime.combine(post_delay_date, dt.time()) + timedelta(seconds=post_delay_seconds)

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
   
    scheduled_time = next_scheduled_time(reminder_time.start, reminder_time.end, reminder_time.days, reminder_time.frequency, datetime.utcnow())
    
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

server = Server()
server.debug()
