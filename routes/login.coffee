common = require('../common')
ctrl = require('ctrl')
model = require('../database/model')
sanitize = require('validator').sanitize

exports.login = (req,res,data) ->
  res.render('home.ect', common.extend({ page: 'Login', req:req }, data))
exports.loginPost = (req, res) ->
  json = req.body
  console.log(json?.email)
  steps = [(step) ->
    console.log("Step 1")
    if !json.email? or json.email == ""
      throw "Please include an email address"
    if !json.password? or json.password == ""
      throw "Please include a password"
    step.next()
  (step) ->
    model.User.find({where: {email: json.email}}).success((user) ->
      step.data.user = user
      step.next()
    ).failure((err) ->
      common.logger.error(err)
      throw "There was a server error")
  (step) ->
    if !step.data.user?
      common.logger.info("Invalid user")
      throw "Invalid username or password."
    if step.data.user.email != json.email
      common.logger.error("Returned user had the wrong email")
      throw "There was an error on the server."
    step.next()
  (step) ->
    if !require('password-hash').verify(sanitize(json.password.toLowerCase()).trim(), step.data.user.password)
      common.logger.info("Invalid password")
      throw "Invalid username or password."
    step.next()
  (step) ->
    req.user.login step.data.user
    step.next()
  ]
  errorHandler = (step, error)->

    json.errorMsg = if error?.message? then error?.message else error.toString()
    common.logger.error(json.errorMsg)
    delete json.password
    exports.login(req, res, json)
  afterSuccessfulLogin = () -> res.redirect('/account.html')
  ctrl(steps, {errorHandler: errorHandler}, afterSuccessfulLogin)

exports.ensureLogin=(req, res, next)->
    if req.user.loggedIn() then next()
    else res.redirect('/login.html')

exports.logout=(req,res)->
    req.user.logout()
    res.redirect('/login.html')
