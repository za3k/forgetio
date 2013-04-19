common = require('../common')
funcflow = require('funcflow')
model = require('../database/model')
sanitize = require('validator').sanitize

exports.login = (req,res,data) ->
  res.render('home.ect', common.extend({ page: 'Login', req:req }, data))
exports.loginPost = (req, res) ->
  json = req.body
  console.log(json)
  steps = [(step, err) ->
    if err? then step.errorHandler(err); return
    if !json.email? or json.email == ""
      step.errorHandler("Please include an email address"); return
    if !json.password? or json.password == ""
      step.errorHandler("Please include a password"); return
    step.next()
  (step, err) ->
    if err? then step.errorHandler(err); return
    model.User.find({where: {email: json.email}}).success(step.next).failure((err) ->
      common.logger.error(err)
      errorHandler("There was a server error"))
  (step, err, user) ->
    if err? then step.errorHandler(err); return
    if !user?
      console.log("Invalid user")
      errorHandler("Invalid username or password."); return
    if user.email != json.email
      common.logger.error("Returned user had the wrong email")
      errorHandler("There was an error on the server."); return
    step.next(user)
  (step, err, user) ->
    if err? then step.errorHandler(err); return
    if !require('password-hash').verify(sanitize(json.password.toLowerCase()).trim(), user.password)
      console.log("Invalid password")
      errorHandler("Invalid username or password."); return
    step.next(user)
  (step, err, user) ->
    if err? then step.errorHandler(err); return
    req.user.login user
    step.next()
  ]
  errorHandler = (error)->
    json.errorMsg =  if error?.message? then error.message else error.toString()
    common.logger.error(json.errorMsg)
    delete json.password
    exports.login(req, res, json)
  funcflow(steps, {errorHandler: errorHandler}, () ->
    res.redirect('/account.html'))

exports.ensureLogin=(req, res, next)->
    if req.user.loggedIn() then next()
    else res.redirect('/login.html')

exports.logout=(req,res)->
    req.user.logout()
    res.redirect('/login.html')
