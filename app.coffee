#!/usr/bin/env coffee
express = require('express')
routes = require('./routes')
http = require('http')
path = require('path')
ect = require('ect')
common = require('./common')
nconf = common.nconf
logger = common.logger

# define some simple middleware
loginUtilMiddleware = (req, res, next)->
    req.user = {
        login:(userId)->req.session.UserId = userId
        logout:()->req.session=null
        loggedIn:()->req.session?.UserId?
        userId:()->req.session?.UserId
    }        
    next()

# create app
app = express()
ectRenderer = ect({ watch: nconf.get("debug"), root: __dirname + '/views' })
logger.debug('App Created!')

app.configure(()->
    app.set('port', nconf.get("httpPort"))
    app.set('views', __dirname + '/views')
    app.engine('ect', ectRenderer.render)
    if !nconf.get("debug") then app.use(express.compress())
    app.use(express.favicon())
    app.use(express.logger('dev'))
    app.use(express.bodyParser())
    app.use(express.methodOverride())
    app.use(express.cookieParser('braSP8pUpR5XuDapHAT9e87ecHUtHufr'))
    app.use(express.cookieSession({cookie: { maxAge: 60 * 60 * 1000 }}))
    app.use(loginUtilMiddleware)
    app.use(app.router)
    app.use(express.static(path.join(__dirname, 'public')))
    app.use((err, req, res, next)-> # Handle any unhandled errors
        if err
            logger.error(err.stack)
            res.send(500, 'Somthing went quite wrong!')
            # res.redirect(500, "500")
        else next()
    )
)
logger.debug('App Configured!')

app.get('/', routes.index)
app.get('/index.html', routes.index)
app.get('/login.html', routes.index)
app.get('/signup.html', routes.signup)
app.post('/signup.html', routes.signupPost)
app.all('*', routes.ensureLogin) # everything below this requires login
app.get('/account.html', routes.account)
app.get('/scheduled.html', routes.scheduled)
app.get('/results.html', routes.results)
app.get('/logout.html', routes.logout)
logger.debug('Routes Configured!')

http.createServer(app).listen(nconf.get("httpPort"), ()->
    logger.debug("Server listening on port #{nconf.get('httpPort')}!")
)
