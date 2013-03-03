#!/usr/bin/env coffee
express = require('express')
routes = require('./routes/all')
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

# common route config info
routeCommonConfig = (req, res, next) ->
    req.config = common.ectConfig
    next()

# handle ALL THE ERRORS
errorMiddleware = (req, res, next)->
  try
    next()
  catch
    logger.error(err.stack)
    res.send(500, 'Somthing went quite wrong!')
        

# create compiler
compiler = require('connect-compiler')({
    enabled:['snockets','less']
    src:['assets','assets/bootstrap/']
    dest:'public'
    options:{
        snockets:{minify:!nconf.get("debug")}
        less:{paths:["./assets/bootstrap/css","./assets/css"],compress:!nconf.get("debug")}
    }
})

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
    app.use(routeCommonConfig)
    app.use(loginUtilMiddleware)
    app.use(app.router)
    app.use(compiler)
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

app.get('/', routes.home)
app.get('/index.html', routes.home)
app.get('/login.html', routes.login)
app.post('/login.html', routes.loginPost)
app.get('/signup.html', routes.signup)
app.post('/signup.html', routes.signupPost)
app.all('*.html', routes.ensureLogin) # everything below this requires login
app.get('/account.html', routes.account)
app.post('/account.html', routes.accountPost)
app.post('/payment.html', routes.paymentPost)
app.get('/scheduled.html', routes.scheduled)
app.post('/scheduled.html', routes.scheduledPost)
app.get('/results.html', routes.results)
app.get('/results/all', routes.csvExportAllReminders)
app.get('/results/:id', routes.csvExportSingleReminder)
app.get('/logout.html', routes.logout)
logger.debug('Routes Configured!')

http.createServer(app).listen(nconf.get("httpPort"), ()->
    logger.debug("Server listening on port #{nconf.get('httpPort')}!")
)
