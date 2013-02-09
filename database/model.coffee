common = require '../common'
nconf = common.nconf
logger = common.logger

extern=(name,value)->module.exports[name]= value

Sequelize = require("sequelize")
sequelize = new Sequelize('notify','postgres','brinksucksballs', {
    host:nconf.get("dbHost")
    port:nconf.get("dbPort")
    dialect:'postgres'
    logging:logger.debug
})
extern("Sequelize",Sequelize)
extern("sequelize",sequelize)
defaultID = {
    type: Sequelize.INTEGER
    autoIncrement: true
    primaryKey: true
    allowNull: false
}
define = (name, options)->
    tmp = sequelize.define(name, options)
    extern(name, tmp)
    return tmp

# Actual Model Starts Here
Phone = define('Phone', {
    Id:defaultID
    Number:{ type:Sequelize.STRING, allowNull:false }
    ConfirmedDate:{ type:Sequelize.DATE, defaultValue:null }
})

User = define('User', {
    Id:defaultID
    Credit:{ type:Sequelize.INTEGER, allowNull:false } # in messages
    Name:{ type:Sequelize.STRING, allowNull:false } 
})

UserRole = define('UserRole', {
    Role:{ type:Sequelize.STRING, allowNull:false }
})
    
Reminder = define('Reminder', {
    Id:{ type: Sequelize.INTEGER, allowNull: false }
    Version:{ type:Sequelize.INTEGER, allowNull:false, defaultValue:0}
    Message:{ type:Sequelize.STRING, allowNull:false, defaultValue:"" }
    Enabled:{ type:Sequelize.BOOLEAN, allowNull:false, defaultValue:true}
})

ReminderTime = define('ReminderTime', {
    Start:{ type:Sequelize.INTEGER, allowNull:false }
    End:{ type:Sequelize.INTEGER, allowNull:false }
    Frequency:{ type:Sequelize.INTEGER, allowNull:false, defaultValue:0 }
    Days:{ type:Sequelize.INTEGER, allowNull:false, defaultValue:0 } # flag field where    1:sun 2:mon 4:tue 8:wed 16:thur 32:fri 64:sat
})

TimeZone = define('TimeZone', {
    Id:defaultID
    Offset:{ type:Sequelize.INTEGER }
    Text:{ type:Sequelize.STRING }
})

# Associations
UserRole.belongsTo(User)
User.hasMany(UserRole)
User.hasMany(Reminder)
User.hasOne(TimeZone)
Reminder.hasMany(ReminderTime)
Reminder.belongsTo(Phone)
Phone.belongsTo(User)
