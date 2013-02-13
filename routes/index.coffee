#!/usr/bin/env coffee
model = require('../database/model')
common = require('../common')
check = require('validator').check
sanitize = require('validator').sanitize
funcflow = require('funcflow')
shared = {}
model.TimeZone.findAll({order: 'id ASC'}).success((db_times) ->
    offset_formatter = (offset, text) ->
        if offset == 0
            text
        else if (offset % 1) == 0
            hours = offset
            minutes = "00"
            "(UTC #{ hours }:#{ minutes }) #{ text }"
        else
            hours = Math.floor(offset) if offset > 0
            hours = Math.ceil(offset) if offset < 0
            minutes = "30"
            "(UTC #{ hours }:#{ minutes }) #{ text }"
    timezones = ({
        id: db_time.id
        text: offset_formatter db_time.offset, db_time.text
    } for db_time in db_times)
    
    shared.timezones = timezones
)

getUser = (req) ->
    model.User.find({where: {id: req.session?.UserId}})

exports.ensureLogin=(req, res, next)->
    if req.user.loggedIn() then next()
    else res.redirect('/login.html')
    
exports.logout=(req,res)->
    req.user.logout()
    res.redirect('/login.html')

exports.index = (req, res) ->
  res.render('home.ect', { page: 'Home', req:req })
  
exports.login = (req,res) ->
    res.render('home.ect', { page: 'Login', req:req })

exports.account = (req, res, data) ->
  getUser(req).success((u) ->
      res.render('account.ect', common.extend({
        page: 'Account'
        timezones: shared.timezones
        req:req
        user: {
          messagesReceived: 5 #TODO
          messagesSent: 20
          timezone: u.TimeZoneId
          name: u.name
          credits: u.credit
          email: u.email
          lowerTimeEstimate: u.credit / 10
          upperTimeEstimate: u.credit / 5
        }
        warningLevel: (daysLeft) ->
            if daysLeft == 0
                "alert alert-error"
            else if 1 < daysLeft < 7
                "alert"
            else if 7 < daysLeft
                "alert alert-info"
      }, data))
  ).failure((err) ->
      console.log(err)
      res.render('account.ect', {
        errMsg: "User not found. Please log in."
      })
    )
exports.accountPost = (req, res) ->
    json = req.body
    steps = [(step, err)->
      getUser(req).success((user)->
        if !user?
          common.logger.error("User does not exist", err)
          step.errorHandler({message:"There was a server error!"})
        else
          step.next(user)
      ).failure((err)->
        common.logger.error("Error saving user's timezone", err)
        step.errorHandler({message:"There was a server error!"}))
    (step, err, user)->
      if err then step.errorHandler(err); return
      if json.timezone == user.TimeZoneId
        exports.account(req, res)
      check(json.timezone, 'Timezone is invalid!').isInt()
      step.next(user, sanitize(json.timezone).toInt())
    (step, err, user, timezone)->
      if err then step.errorHandler(err); return
      user.TimeZoneId =  timezone
      user.save().success(step.next).failure((err)->
        common.logger.error("Error saving user's timezone", err)
        step.errorHandler({message:"There was a server error!"}))
    (step, err, user)->
      if err then step.errorHandler(err); return
      exports.account(req, res)
      step.next()
    ]
    errorHandler = (error)->
      json.errorMsg =  if error?.message? then error.message else error.toString()
      common.logger.error(json.errorMsg)
      exports.account(req, res, json)
    funcflow(steps, {errorHandler:errorHandler},()->{})

signup = (req, res, data={})->
    res.render('signup.ect', common.extend({
        page: 'Signup'
        req:req
        timezones: shared.timezones}, data))
exports.signup=(req, res)->signup(req,res)
exports.signupPost = (req, res) ->
    json = req.body
    steps = [(step,err)->
        # validate the data
        check(json.name, 'Name is required!').len(4,255)
        check(json.TimeZoneId, 'Timezone is invalid!').isInt()
        check(json.email, 'Email is invalid!').len(4,255).isEmail()
        check(json.password, 'Password must be at least 8 characters!').len(8,255)
        # sanitize the data
        json.email = sanitize(json.email.toLowerCase()).trim()
        json.password = require('password-hash').generate(sanitize(json.password.toLowerCase()).trim())
        json.name = sanitize(json.name).trim()
        json.TimeZoneId = sanitize(json.TimeZoneId).toInt()
        step.next()
    (step,err)->
        if err then step.errorHandler(err); return
        # check if email already exists
        model.User.find({where:{email:json.email}})
            .success(step.next)
            .error((err)->
                common.logger.error("Error retrieving user by email", err)
                step.errorHandler({message:"There was a server error!"}))
    (step,err,user)->
        if user? then step.errorHandler({message:"A user with that email already exists!"}); return
        # save the new user!
        user = model.User.build(json)
        console.dir(user)
        user.save()
            .success(()->step.next(user))
            .error((err)->
                common.logger.error("Error saving user", err)
                step.errorHandler({message:"There was a server error!"}))
    (step,err,user)->
        # log the user in!
        req.session.UserId = user.id
        step.next()
    ]
    errorHandler = (error)->
        delete json.password
        json.errorMsg =  if error?.message? then error.message else error.toString()
        signup(req, res, json)
    funcflow(steps, {errorHandler:errorHandler},()->res.redirect('/scheduled.html'))

timesOfDay = (
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
exports.scheduled = (req, res) ->
  res.render('scheduled.ect', { 
    req:req
    page: 'Scheduled' 
    daysOfWeek: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    beginTimesOfDay: timesOfDay[...-1]
    endTimesOfDay: timesOfDay[1..]
    reminders: [
        {
         message: "How happy are you right now on a scale of 0-10?"
         times: [
             {
              frequency: 5
              start: 7
              end: 9
              days: ["Tue","Wed","Thu","Fri","Sat","Sun"]
              enabled: true
             },
             {
              frequency: 5
              start: 17.5
              end: 24
              days: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
              enabled: false
             }
         ]
        },
        {
         message: "How curious are you right now on a scale of 0-10?"
         times: [
             {
              frequency: 5
              start: 7
              end: 9
              days: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
              enabled: false
             },
             {
              frequency: 5
              start: 17.5
              end: 21
              days: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
              enabled: false
             }
         ]
        }
    ]
  })

exports.results = (req, res) ->
  res.render('results.ect', { page: 'Results', req:req })
