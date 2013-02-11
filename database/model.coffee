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
define = (name, options)->
    tmp = sequelize.define(name, options)
    extern(name, tmp)
    return tmp

# Actual Model Starts Here
Phone = define('Phone', {
    id:defaultID
    number:{ type:Sequelize.STRING, allowNull:false }
    confirmedDate:{ type:Sequelize.DATE, defaultValue:null }
})

User = define('User', {
    id:defaultID
    credit:{ type:Sequelize.INTEGER, allowNull:false } # in messages
    name:{ type:Sequelize.STRING, allowNull:false } 
})

UserRole = define('UserRole', {
    role:{ type:Sequelize.STRING, allowNull:false }
})
    
Reminder = define('Reminder', {
    id:defaultID
    parentId:{type:Sequelize.INTEGER, allowNull:true, defaultValue:null }
    version:{ type:Sequelize.INTEGER, allowNull:false, defaultValue:0 }
    message:{ type:Sequelize.STRING, allowNull:false, defaultValue:"" }
    enabled:{ type:Sequelize.BOOLEAN, allowNull:false, defaultValue:true }
})

ReminderTime = define('ReminderTime', {
    start:{ type:Sequelize.INTEGER, allowNull:false }
    end:{ type:Sequelize.INTEGER, allowNull:false }
    frequency:{ type:Sequelize.INTEGER, allowNull:false, defaultValue:0 }
    days:{ type:Sequelize.INTEGER, allowNull:false, defaultValue:0 } # flag field where    1:sun 2:mon 4:tue 8:wed 16:thur 32:fri 64:sat
},{
    instanceMethods: {
        getDays:()->[(@days&1)==1,(@days&2)==2,(@days&4)==4,(@days&8)==8,(@days&16)==16,(@days&32)==32,(@days&64)==64]
        setDays:(d)->@days=(d[0]&&1||0)|(d[1]&&2||0)|(d[2]&&4||0)|(d[3]&&8||0)|(d[4]&&16||0)|(d[5]&&32||0)|(d[6]&&64||0)
    }
})

TimeZone = define('TimeZone', {
    id:defaultID
    offset:{ type:Sequelize.FLOAT, allowNull:false }
    text:{ type:Sequelize.STRING, allowNull:false }
})

# Associations
User.hasMany(UserRole, {as:'Roles'})
User.hasMany(Reminder, {as:'Reminders'})
User.belongsTo(TimeZone, {as:'TimeZone'})
Reminder.hasMany(ReminderTime, {as:'Times'})
Reminder.belongsTo(Phone, {as:'Phone'})
Phone.belongsTo(User, {as:'User'})
