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
    httpPort:3001
    debug:true
    logFile:'notify.log'
    dbPort:5432
    dbHost:'127.0.0.1'
    appName:'Reminder'
})
module.exports.nconf = nconf

# setup logger
logger = require('winston')
logger.add(logger.transports.File, { filename: nconf.get('logFile'), handleExceptions:!nconf.get('debug'), exitOnError: false })
logger.debug('Logger Initialized!')
module.exports.logger = logger

# shared configuration for routes
model = require('./database/model')
module.exports.ectConfig = {}
model.TimeZone.findAll({order: 'id ASC'}).success((db_times) ->
    offset_formatter = (offset, text) ->
        if offset == 0
            text
        else if (offset % 3600) == 0
            hours = offset / 3600
            minutes = "00"
            "(UTC #{ hours }:#{ minutes }) #{ text }"
        else
            hours = Math.floor(offset / 3600) if offset > 0
            hours = Math.ceil(offset / 3600) if offset < 0
            minutes = Math.floor(Math.abs((offset % 3600) / 60))
            "(UTC #{ hours }:#{ minutes }) #{ text }"
    timezones = ({
        id: db_time.id
        text: offset_formatter db_time.offset, db_time.text
    } for db_time in db_times)
    
    module.exports.ectConfig.timezones = timezones
)

module.exports.timesOfDay = (
    {
        value: v
        text: if v in [0, 24]
            "Midnight"
        else if v == 12
            "Noon"
        else if v < 12
            "#{v}:00am"
        else
            "#{v-12}:00pm"
    } for v in [0..24]
)

module.exports.getUser = (req) ->
    model.User.find({where: {id: req.session?.UserId}})

module.exports.ectConfig.appName = nconf.get('appName')
