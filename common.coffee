# load config
nconf = require('nconf')
nconf.env().argv() # process.env and process.argv
nconf.file('config.json')
nconf.defaults({
    httpPort:3000
    debug:true
    logFile:'notify.log'
    dbPort:5432
    dbHost:'127.0.0.1'
})
module.exports.nconf = nconf

# setup logger
logger = require('winston')
logger.add(logger.transports.File, { filename: nconf.get('logFile'), handleExceptions:true, exitOnError: false })
logger.debug('Logger Initialized!')
module.exports.logger = logger