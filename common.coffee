#debugger;

# patch Date object to support time zones
require('time')(Date)

# some util methods
_ = require 'underscore'
module.exports.flatten = _.flatten
module.exports.extend = _.extend
module.exports._ = _

# load config
nconf = require('nconf')
nconf.env().argv() # process.env and process.argv
nconf.file('config.json')
nconf.defaults({
    httpPort:9001
    debug:false
    logFile:'notify.log'
    dbPort:5432
    dbHost:'127.0.0.1'
    appName:'Reminder'
})
module.exports.nconf = nconf

# setup logger
logger = require('winston')
logger.add logger.transports.File, 
    filename: nconf.get('logFile'), 
    handleExceptions:true, 
    exitOnError:true
logger.remove logger.transports.Console
logger.add logger.transports.Console,
    level: "info"
logger.debug('Logger Initialized!')
module.exports.logger = logger

# shared configuration for routes
model = require('./database/model')
module.exports.ectConfig = {}
model.TimeZone.findAll({order: 'id ASC'}).success((db_times) ->
    timezones = ({
        id: db_time.id
        text: offsetDisplayName db_time.offset, db_time.text
    } for db_time in db_times)
    
    module.exports.ectConfig.timezones = timezones
)

offsetDisplayName = (offset, text) ->
    if offset == 0
        text
    else
        {hours, minutes} = offsetToHoursAndMinutes offset
        "(UTC #{ hours }:#{ minutes }) #{ text }"

offsetToHoursAndMinutes = (offset) ->
    if offset == 0
        {
            hours: 0
            minutes: 0
        }
    else if (offset % 3600) == 0
        {
            hours: offset / 3600
            minutes: 0
        }
    else
        hours = Math.floor(offset / 3600) if offset > 0
        hours = Math.ceil(offset / 3600) if offset < 0
        {
            hours: hours
            minutes: Math.floor(Math.abs((offset % 3600) / 60))
        }

timeOfDayDisplayName = (timeOfDay) ->
    if v in [0, 24]
        "Midnight"
    else if v == 12
        "Noon"
    else if v < 12
        "#{v}:00am"
    else
        "#{v-12}:00pm"

module.exports.timesOfDay = (
    {
        value: v
        text: timeOfDayDisplayName v
    } for v in [0..24]
)

module.exports.getUser = (req) ->
    model.User.find({where: {id: req.user.userId()}})

module.exports.ectConfig.appName = nconf.get('appName')
