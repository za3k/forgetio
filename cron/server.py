from bottle import route, run, template, request
from datetime import datetime, timedelta
from sqlalchemy import create_engine, desc
from sqlalchemy.orm import sessionmaker
from sqlalchemy.sql import select
from sql_def import User, Phone, Reminder, SentMessage, ReceivedMessage
import json
import time, threading

engine = create_engine('postgresql://localhost/zachary', echo=True)
# create a Session
Session = sessionmaker(bind=engine)

@route('/sms/status', method='POST')
def receive_sms_status():
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
    schedule_message_to_send(body="Why do you say \"{}\"".format(message.body), to=message.from_)

def schedule_message_to_send(body, to="+15135495690", from_="+15132015132", time=None):
    """time of None means 'now'"""
    if time is None:
        time = datetime.utcnow()
    session = Session()
    message = SentMessage(
        account = "AC84c3eee95bf50e49e7bbd0f1e42e530b",
        from_=from_,
        to=to,
        body=body,
        scheduled=time)
    session.add(message)
    session.commit()

def scheduled_messages(before_time=None):
    if before_time is None:
        before_time = datetime.utcnow()
        
    session = Session()
    s = session.query(SentMessage)
    s = s.filter(SentMessage.server_sent == None)
    s = s.filter(SentMessage.scheduled <= before_time)
    return session, s.all()
def send_all_scheduled_messages():
    session, messages = scheduled_messages()
    for message in messages:
        send_scheduled_message(message)
        session.add(message)
        session.commit()
def send_scheduled_message(message):
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
        print("Looking for messages to send...")
        schedule_messages()
        send_all_scheduled_messages()
        send_emails()
        print("    Done.")

def schedule_messages():
    '''find users without a scheduled messages and schedule them one'''
    # Let's be realistic -- make this more efficient once we need to.
    session = Session()
    for user in session.query(User):
        if user.credit <= 0:
            continue
        phone = user.selected_phone
        q = session.query(SentMessage)
        q = q.filter(SentMessage.to == phone.number)
        q = q.filter(SentMessage.server_sent == None)
        queued_messages = q.count()
        print("QUEUED MESSAGES: {}".format(queued_messages))
        if queued_messages == 0:
            schedule_reminders_for_user(user)
    session.commit()

def schedule_reminders_for_user(user):
    assert(len(user.reminders)==1)
    schedule_reminder(user.reminders[0])
def schedule_reminder(reminder):
    import random
    delay = timedelta_times(reminder.frequency, random.expovariate(1))
    scheduled_time=datetime.utcnow()+delay
    print(delay)
    #print(datetime.utcnow())
    print(scheduled_time)
    #print(reminder.frequency)
    print(reminder.message)
    schedule_message_to_send(
        body=reminder.message,
        to=reminder.user.selected_phone.number,
        time=scheduled_time)

def timedelta_times(td, c):
    return timedelta(seconds=td.total_seconds()*c)
    

def send_emails():
    # see if any users should be emailed about their responses (nightly?)
    pass

server = Server()
server.debug()


def init_db():
    session = Session()
    user = User(credit=1000, selected_phone=Phone(number="+15135495690"))
    user.selected_phone.user = user
    user.reminders = [Reminder(frequency=timedelta(minutes=1),message="Remember the Alamo",enabled=True)]

    session.add_all([user])
    session.commit()

#init_db()
#schedule_message_to_send(body="Testing3", to="+15135495690", from_="+15132015132")
