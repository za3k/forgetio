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
module.exports.ectConfig = 
module.exports.ectConfig = {}
require('./ectConfig').timezones (timezones) ->
    module.exports.ectConfig.timezones = timezones
module.exports.ectConfig.appName = nconf.get('appName')

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