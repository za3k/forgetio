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

exports.account = (req, res) ->
  res.render('account.ect', {
    page: 'Account'
    timezones: shared.timezones
    req:req
  })
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
        require('password-hash').generate(sanitize(json.password.toLowerCase()).trim())
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

exports.scheduled = (req, res) ->
  res.render('scheduled.ect', { 
    req:req
    page: 'Scheduled' 
    daysOfWeek: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    timesOfDay: [
        {
         value:7
         text:"7:00am"
        },
        {
         value:9
         text:"9:00am"
        },
        {
         value:17.5
         text:"5:30pm"
        },
        {
         value:21
         text:"9:00pm"
        },
        {
         value:24
         text:"Midnight"
        }
    ]
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
