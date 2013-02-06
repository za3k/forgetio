#!/usr/bin/env coffee
express = require('express')
routes = require('./routes')
http = require('http')
path = require('path')
ect = require('ect')
nconf = require('nconf')

# load config
nconf.env().argv() # process.env and process.argv
nconf.file('config.json')
nconf.defaults({
    PORT:3000
    debug:true
    logFile:'notify.log'
})

# setup logger
winston = require('winston')
winston.add(winston.transports.File, { filename: nconf.get('logFile'), handleExceptions:true, exitOnError: false })
winston.debug('Logger Initialized!')

# create app
app = express()
ectRenderer = ect({ watch: nconf.get("debug"), root: __dirname + '/views' })
winston.debug('App Created!')

app.configure(()->
    app.set('port', nconf.get("PORT"))
    app.set('views', __dirname + '/views')
    app.engine('ect', ectRenderer.render)
    if !nconf.get("debug") then app.use(express.compress())
    app.use(express.favicon())
    app.use(express.logger('dev'))
    app.use(express.bodyParser())
    app.use(express.methodOverride())
    app.use(express.cookieParser('braSP8pUpR5XuDapHAT9e87ecHUtHufr'))
    app.use(express.cookieSession({cookie: { maxAge: 60 * 60 * 1000 }}))
    app.use(app.router)
    app.use(express.static(path.join(__dirname, 'public')))
    app.use((err, req, res, next)-> # Handle any unhandled errors
        if err
            winston.error(err.stack)
            res.send(500, 'Somthing went quite wrong!')
            # res.redirect(500, "500")
        else next()
    )
)
winston.debug('App Configured!')

app.get('/', routes.index)
winston.debug('Routes Configured!')

http.createServer(app).listen(app.get('port'), ()->
    winston.debug("Server listening on port #{app.get('port')}!")
)
