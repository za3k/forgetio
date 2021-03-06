pg = require 'pg'
#common = require '../common'
#nconf = common.nconf
#logger = common.logger
logger = () ->


extern=(name,value)->module.exports[name]= value

communication = "SELECT reminders.id AS reminder_id, reminders.version, reminder_times.id AS reminder_time_id, users.id AS user_id, reminders.message, sent_messages.scheduled, sent_messages.cancelled, received_messages.server_received, received_messages.body as received_body, sent_messages.body as sent_body, sent_messages.to AS sent_to, received_messages.from_ as received_from FROM users,reminders,reminder_times,sent_messages LEFT JOIN received_messages ON (sent_messages.id = received_messages.in_response_to) WHERE (users.id = reminders.user_id AND reminders.id = reminder_times.reminder_id AND sent_messages.sent_for_reminder_time_id = reminder_times.id AND sent_messages.cancelled = false) ORDER BY scheduled DESC"

communication_admin = "SELECT reminders.user_id AS user_id, reminders.id AS reminder_id, reminders.version, reminder_times.id AS reminder_time_id, users.id AS user_id, reminders.message, sent_messages.scheduled, sent_messages.cancelled, received_messages.server_received, received_messages.body as received_body, sent_messages.body as sent_body, sent_messages.to AS sent_to, received_messages.from_ as received_from FROM users,reminders,reminder_times,sent_messages LEFT JOIN received_messages ON (sent_messages.id = received_messages.in_response_to) WHERE (reminders.id = reminder_times.reminder_id AND sent_messages.sent_for_reminder_time_id = reminder_times.id AND sent_messages.cancelled = false) ORDER BY scheduled DESC"

extern "getCommunication", (user, cb) ->
        common.logger.debug("getCommunication")
        query = communication
        if user.id == 1
            query = communication_admin
        
        pg.connect "tcp://localhost/notify", (err, client, done) ->
            common.logger.debug("pg.connect returned")
            common.logger.debug(err)
            common.logger.debug(common._.isUndefined(client))
            common.logger.debug(common._.isNull(client))
            if err?
                cb err, null
            common.logger.debug(query)
            client.query query, (err, result) ->
                common.logger.debug("query returned")
                if err?
                    cb err, null
                else
                    cb err, result.rows.filter (x) -> x.user_id == user.id
                done()

successFail = extern "successFail", (dbcall, cb) ->
    dbcall.success((x) -> cb(x)).failure((err) -> cb(undefined, err))

extern "getUserForId", (id, cb) ->
  successFail User.find({where: {id: id}}), cb

extern "getUserForEmail", (email, cb) ->
  successFail User.find({where:{email:email}}), cb

extern "saveUser", (user, cb) ->
  successFail user.save(), cb

extern "createUserPayment", (payment, cb) ->
  successFail UserPayment.create(payment), cb

extern "updateUser", (user, changelist, cb) ->
  successFail user.updateAttributes(changelist), cb

extern "updateUserPayment", (userPayment, changelist, cb) ->
  successFail userPayment.updateAttributes(changelist), cb

extern "findAllTimezones", (cb) ->
  successFail TimeZone.findAll({order: 'id ASC'}), cb

Sequelize = require("sequelize")
sequelize = new Sequelize('notify','postgres','brinksucksballs', {
    host:'notify2'
    #port:nconf.get("dbPort")
    dialect:'postgres'
    logging:logger.debug
    omitNull:true
    define:{
    }
})
extern("Sequelize",Sequelize)
extern("sequelize",sequelize)
defaultID = {
    type: Sequelize.INTEGER
    autoIncrement: true
    primaryKey: true
}
define = (name, dbname, options)->
    tmp = sequelize.define(dbname, options)
    extern(name, tmp) #Don't export these--total encapsulation is the new goal
    return tmp

module.exports.chainer = sequelize.queryChainer

# Actual Model Starts Here
Phone = define('Phone', 'phones', {
    id:defaultID
    number:{ type:Sequelize.STRING, allowNull:false }
    confirmedDate:{ type:Sequelize.DATE, defaultValue:null }
})

User = define('User', 'users', {
    id:defaultID
    credit:{ type:Sequelize.INTEGER, allowNull:false, defaultValue:0} # in messages
    name:{ type:Sequelize.STRING }
    email:{ type:Sequelize.STRING, allowNull:false}
    password:{ type:Sequelize.STRING, allowNull:false }
})

UserPayment = define('UserPayment', 'user_payments', {
    id:defaultID
    credit:{ type:Sequelize.INTEGER } # in messages
    money:{ type:Sequelize.INTEGER } # in cents
    stripe_fee:{ type:Sequelize.INTEGER } # in cents
    stripe_token:{ type:Sequelize.STRING }
    stripe_charge:{ type:Sequelize.STRING }
})

#Enable once needed
#UserRole = define('UserRole', {
#    role:{ type:Sequelize.STRING, allowNull:false }
#})
    
Reminder = define('Reminder', 'reminders', {
    id:defaultID
    version:{ type:Sequelize.INTEGER, allowNull:false, defaultValue:0 }
    message:{ type:Sequelize.STRING, allowNull:false, defaultValue:"" }
})

ReminderTime = define('ReminderTime', 'reminder_times', {
    start:{ type:Sequelize.INTEGER, allowNull:false } # in seconds since midnight
    end:{ type:Sequelize.INTEGER, allowNull:false }
    frequency:{ type:Sequelize.FLOAT, allowNull:false, defaultValue:0 }
    days:{ type:Sequelize.INTEGER, allowNull:false, defaultValue:0 } # flag field where    1:sun 2:mon 4:tue 8:wed 16:thur 32:fri 64:sat
},{
    instanceMethods: {
        getDays:()->[(@days&1)==1,(@days&2)==2,(@days&4)==4,(@days&8)==8,(@days&16)==16,(@days&32)==32,(@days&64)==64]
        setDays:(d)->@days=(d[0]&&1||0)|(d[1]&&2||0)|(d[2]&&4||0)|(d[3]&&8||0)|(d[4]&&16||0)|(d[5]&&32||0)|(d[6]&&64||0)
    }
})

SentMessage = define('SentMessage', 'sent_messages', {
    id:defaultID
    account: {type:sequelize.STRING, allowNull:false }
    twilio_id: {type:sequelize.STRING, allowNull:false }
    from_: {type:sequelize.STRING, allowNull:false }
    to: {type:sequelize.STRING, allowNull:false }
    body: {type:sequelize.STRING, allowNull:false }
    scheduled: {type:sequelize.DATE, allowNull:false }
    api_version: {type:sequelize.STRING, allowNull:false }
    server_sent: {type:sequelize.DATE, allowNull:true }
    server_confirmed: {type:sequelize.DATE, allowNull:true }
    twilio_status: {type:sequelize.STRING, allowNull:false }
    twilio_uri: {type:sequelize.STRING, allowNull:false }
    was_processed_after_confirm: {type:sequelize.BOOLEAN, allowNull:false, default:false }
    cancelled: {type:sequelize.BOOLEAN, allowNull:false, default:false }
})

ReceivedMessage = define('ReceivedMessage', 'received_messages', {
    id:defaultID
    account: {type:sequelize.STRING, allowNull:false }
    twilio_id: {type:sequelize.STRING, allowNull:false }
    from_: {type:sequelize.STRING, allowNull:false }
    to: {type:sequelize.STRING, allowNull:false }
    body: {type:sequelize.STRING, allowNull:false }
    server_received: {type:sequelize.DATE, allowNull:true }
    api_version: {type:sequelize.STRING, allowNull:false }
    twilio_status: {type:sequelize.STRING, allowNull:true }
    was_processed_after_received: {type:sequelize.BOOLEAN, allowNull:false, default:false }
})

TimeZone = define('TimeZone', 'timezones', {
    id:defaultID
    offset:{ type:Sequelize.INTEGER, allowNull:false } # in seconds from UTC
    text:{ type:Sequelize.STRING, allowNull:false }
})

# Associations
#User.hasMany(UserRole, {as:'Roles'})
User.hasMany(Reminder, {as:'Reminders', foreignKey: "user_id"})
User.belongsTo(TimeZone, {as:'TimeZone', foreignKey: "timezone_id"})
Reminder.hasMany(ReminderTime, {as:'Times', foreignKey: "reminder_id"})
Reminder.belongsTo(Phone, {as:'Phone', foreignKey: "phone_id"})
Phone.belongsTo(User, {as:'User', foreignKey: "user_id"})
SentMessage.belongsTo(ReminderTime, {as:'ReminderTime', foreignKey: "sent_for_reminder_time_id"})
ReceivedMessage.belongsTo(SentMessage, {as:'InResponseTo', foreignKey: "in_response_to"})
