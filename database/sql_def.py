from sqlalchemy import create_engine, ForeignKey, ForeignKeyConstraint, UniqueConstraint
from sqlalchemy.orm import relationship, backref
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, Interval, Boolean, DateTime

engine = create_engine('postgresql://localhost/notify', echo=True)
Base = declarative_base()

class Phone(Base):
    __tablename__ = 'phones'
    __table_args__ = (
            UniqueConstraint("id", "user_id"),
            )
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    number = Column(String)
    confirmed_date = Column(DateTime)
    user = relationship("User", 
            backref=backref("phones"), 
            primaryjoin="User.id==Phone.user_id", 
            foreign_keys=user_id)
    createdAt = Column(DateTime)
    updatedAt = Column(DateTime)

class User(Base):
    __tablename__ = 'users'

    id = Column(Integer, primary_key=True, autoincrement='ignore_fk')
    credit = Column(Integer) # in messages
    name = Column(String)
    email = Column(String)
    password = Column(String) # salted
    timezone_id = Column(Integer, ForeignKey("timezones.id"))
    createdAt = Column(DateTime)
    updatedAt = Column(DateTime)

    timezone = relationship("Timezone")

class Reminder(Base):
    __tablename__ = 'reminders'
    
    id = Column(Integer, primary_key=True)
    version = Column(Integer)
    parent_id = Column(Integer, ForeignKey('reminders.id'))
    user_id = Column(Integer, ForeignKey('users.id'))
    phone_id = Column(Integer, ForeignKey('phones.id'))
    frequency = Column(Interval)
    message = Column(String(160))
    createdAt = Column(DateTime)
    updatedAt = Column(DateTime)
   
    user = relationship("User", backref='reminders', order_by=id)
    children = relationship("Reminder", backref=backref("parent"), remote_side=[id])
    phone = relationship("Phone")

class ReminderTime(Base):
    __tablename__ = "reminder_times"
    
    id = Column(Integer, primary_key=True)
    start = Column(Integer) # seconds since midnight
    end = Column(Integer) # seconds since midnight
    frequency = Column(Integer)
    days = Column(Integer) # flag field where    1:sun 2:mon 4:tue 8:wed 16:thur 32:fri 64:sat
    reminder_id = Column(Integer, ForeignKey('reminders.id'))
    createdAt = Column(DateTime)
    updatedAt = Column(DateTime)
    
    reminder = relationship("Reminder", backref='times', order_by=id)

class SentMessage(Base):
    __tablename__ = 'sent_messages'

    id = Column(Integer, primary_key=True)
    sent_for_reminder_id = Column(Integer, ForeignKey('reminders.id'))
    account = Column(String)
    twilio_id = Column(String)
    from_ = Column(String)
    to = Column(String)
    body = Column(String)
    scheduled = Column(DateTime)
    api_version = Column(String)
    server_sent = Column(DateTime)
    server_confirmed = Column(DateTime)
    twilio_status = Column(String)
    twilio_uri = Column(String)
    was_processed_after_confirm = Column(Boolean)

    sent_for_reminder = relationship("Reminder")

class ReceivedMessage(Base):
    __tablename__ = 'received_messages'

    account = Column(String)
    twilio_id = Column(String, primary_key=True)
    from_ = Column(String)
    to = Column(String)
    body = Column(String)
    server_received = Column(DateTime)
    api_version = Column(String)
    twilio_status = Column(String)
    in_response_to = Column(Integer, ForeignKey('sent_messages.id'))
    was_processed_after_received = Column(Boolean)

class Timezone(Base):
    __tablename__ = "timezones"

    id = Column(Integer, primary_key=True)
    offset = Column(Integer)
    text = Column(String)
    createdAt = Column(DateTime)
    updatedAt = Column(DateTime)

Base.metadata.create_all(engine)
