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

class User(Base):
    __tablename__ = 'users'
    __table_args__ = (
            ForeignKeyConstraint(
                ["id", "selected_phone_id"],
                ["phones.user_id", "phones.id"],
                use_alter=True, name="fk_selected_phone",
                ),
            )

    id = Column(Integer, primary_key=True, autoincrement='ignore_fk')
    credit = Column(Integer) # in messages
    selected_phone_id = Column(Integer)
    selected_phone = relationship("Phone", 
            primaryjoin="User.selected_phone_id==Phone.id", 
            foreign_keys=selected_phone_id, 
            post_update=True)

class Reminder(Base):
    __tablename__ = 'reminders'
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    frequency = Column(Interval)
    message = Column(String(160))
    reply_format = Column(String)
    enabled = Column(Boolean)
   
    user = relationship("User", backref='reminders', order_by=id)

class SentMessage(Base):
    __tablename__ = 'sent_messages'

    id = Column(Integer, primary_key=True)
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

Base.metadata.create_all(engine)
