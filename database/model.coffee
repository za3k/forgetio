common = require '../common'
nconf = common.nconf
logger = common.winston

extern=(name,value)->module.exports[name]= value

Sequelize = require("sequelize")
sequelize = new Sequelize('notify','postgres','brinksucksballs', {
    host:nconf.get("dbHost")
    port:nconf.get("dbPort")
    dialect:'postgres'
})
extern("Sequelize",Sequelize)
extern("sequelize",sequelize)
defaultID = {
    type: Sequelize.INTEGER
    autoIncrement: true
    primaryKey: true
}
define = (name, options)->
    tmp = sequelize.define(name, options)
    extern(name, tmp)
    return tmp

# Actual Model Starts Here
Phone = define('Phone', {
    id:defaultID
    number:{ type:Sequelize.STRING }
    confirmedDate:{ type:Sequelize.DATE }
})

User = define('User', {
    id:defaultID
    credit:{ type:Sequelize.INTEGER } # in messages
})

UserRole = define('UserRole', {
    role:{ type:Sequelize.STRING }
})
    
Reminder = define('Reminder', {
    id:defaultID
    message:{ type:Sequelize.STRING }
    enabled:{ type:Sequelize.BOOLEAN }
    frequency:{ type:Sequelize.INTEGER } #in seconds
    replyFormat:{ type:Sequelize.STRING }
})

ReminderTime = define('ReminderTime', {
    start:{ type:Sequelize.DATE }
    end:{ type:Sequelize.DATE }
})

# Associations
User.hasMany(UserRole)
User.hasMany(Reminder)
Reminder.hasMany(ReminderTime)
Reminder.hasOne(Phone)




    