#!/usr/bin/env coffee
model = require('../database/model')
transaction = require('../database/trans')
common = require('../common')
check = require('validator').check
sanitize = require('validator').sanitize
funcflow = require('funcflow')
shared = {}
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

exports.home = (req, res) ->
  res.render('home.ect', { page: 'Home', req:req })
  
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
    req.session.UserId = user.id
    step.next()
  ]
  errorHandler = (error)->
    json.errorMsg =  if error?.message? then error.message else error.toString()
    common.logger.error(json.errorMsg)
    delete json.password
    exports.login(req, res, json)
  funcflow(steps, {errorHandler: errorHandler}, () ->
    res.redirect('/account.html'))

exports.account = (req, res, data) ->
  getUser(req).success((u) ->
      res.render('account.ect', common.extend({
        page: 'Account'
        timezones: shared.timezones
        req:req
        user: {
          messagesReceived: 5 #TODO
          messagesSent: 20
          timezone: u.timezone_id
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
      if json.timezone == user.timezone_id
        exports.account(req, res)
      check(json.timezone, 'Timezone is invalid!').isInt()
      step.next(user, sanitize(json.timezone).toInt())
    (step, err, user, timezone)->
      if err then step.errorHandler(err); return
      user.timezone_id =  timezone
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
        json.timezone_id = json.TimeZoneId
        delete json.TimeZoneId
        # validate the data
        check(json.name, 'Name is required!').len(4,255)
        check(json.timezone_id, 'Timezone is invalid!').isInt()
        check(json.email, 'Email is invalid!').len(4,255).isEmail()
        check(json.password, 'Password must be at least 8 characters!').len(8,255)
        # sanitize the data
        json.email = sanitize(json.email.toLowerCase()).trim()
        json.password = require('password-hash').generate(sanitize(json.password.toLowerCase()).trim())
        json.name = sanitize(json.name).trim()
        json.timezone_id = sanitize(json.timezone_id).toInt()
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

emptyTime = {
  enabled: false
  days: []
}

emptyReminder = {
  times: [emptyTime, emptyTime]
}

getRemindersForUser = (user, cb) ->
  steps = [
    (step, err) ->
        if err then step.errHandler(err); return
        step.user.getReminders().success step.next
    (step, err, reminders) ->
        if err then step.errHandler(err); return
        step.reminders = []
        for r in reminders
          reminder = {
            message: r.message
            id: r.id
            version: r.version
            parentId: r.parentId
            times: []
          }
          reminder_steps = [
            (step2, err) ->
              if err then step.errHandler(err); return
              time_cb = step2.spawn()
              phone_cb = step2.spawn()
              step2.r.getTimes().success (ts) ->
                for t in ts
                  time = {
                    frequency: t.frequency
                    start: t.start / 60 / 60
                    end: t.end / 60 / 60
                    enabled: true
                    days: []
                  }
                  d = t.days
                  for day in ["Sun", "Mon", "Tue", "Wed", "Thu", "Sat", "Sun"]
                    if (d % 2) == 1
                      time.days.push(day)
                      d -= 1
                    d /= 2
                  step2.reminder.times.push(time)
                time_cb()
              step2.r.getPhone().success (p) ->
                  step2.reminder.phone = p.number
                  phone_cb()
              step2.next()
            (step2) ->
                step2.next()
          ]
          cb = step.spawn()
          funcflow(reminder_steps, {reminder: reminder, r:r, errHandler: step.errHandler, catchExceptions: false}, (step2, err, reminder) ->
            if err then step.errHandler(err); return
            step.reminders.push(step2.reminder)
            cb())
        step.next()
  ]
  last = (step) ->
    for r in step.reminders
      if !r.parentId?
        r.parentId = r.id
    step.reminders = step.reminders.filter (reminder) ->
      for r in step.reminders
        if r.parentId == reminder.parentId and r.version > reminder.version
          return false
      return true
    step.cb(step.reminders)
  
  errHandler = (err) ->
    console.log("There was an error")
    console.log(err)
  funcflow(steps, {errHandler: errHandler, cb: cb, user: user}, last)

putReminderForUser = (reminder, user, success, failure) ->
  reminder.user_id = user.id
  console.log("Putting reminder: " + reminder)
  for time in reminder.times
    time.start = time.start * 60 * 60 # seconds since midnight
    time.end = time.end * 60 * 60
    time.days = (x in time.days for x in ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
    d = 0
    while time.days.length > 0
      d *= 2
      d += time.days.pop()
    time.days = d
  reminder.times = reminder.times.filter (time) ->
    if !time.frequency
        return false
    return true
  if !reminder.message or reminder.message == ""
    failure("Message was blank")
  if !reminder.phone or reminder.phone == ""
    failure("Phone number was blank")
    
  trans = transaction.createSaveReminderTran(reminder)
  transaction.runTran(trans, success)

exports.scheduled = (req, res, data) ->
  getUser(req).success (user) ->
    getRemindersForUser(user, (reminders) ->
      for r in reminders
        r.times.push(emptyTime)
      reminders.push(emptyReminder)
      res.render('scheduled.ect', common.extend({
        req:req
        page: 'Scheduled'
        daysOfWeek: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        beginTimesOfDay: timesOfDay[...-1]
        endTimesOfDay: timesOfDay[1..]
        defaultPhone: "+1 (555) 555-5555"
        reminders: reminders
      }, data)))

exports.scheduledPost = (req, res) ->
  getUser(req).success (user) ->
    console.log(req.body)
    json = JSON.parse(req.body.json)
    for reminder in json.reminders
      putReminderForUser(reminder, user, () ->
        exports.scheduled(req, res, {successMsg: "Successfully updated."})
      (errMsg) ->
        exports.scheduled(req, res, {errorMsg: errMsg}))
        

exports.results = (req, res) ->
  res.render('results.ect', { page: 'Results', req:req })
