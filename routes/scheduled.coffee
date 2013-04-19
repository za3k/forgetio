transaction = require('../database/trans')
common = require('../common')
funcflow = require('funcflow')
check = require('validator').check
sanitize = require('validator').sanitize

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
            error: r.error
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
                  for day in ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
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
      if !r.parent_id?
        r.parentId = r.id
    step.reminders = step.reminders.filter (reminder) ->
      for r in step.reminders
        if r.parent_id == reminder.parent_id and r.version > reminder.version
          return false
      return true
    step.cb(step.reminders)
  
  errHandler = (err) ->
    console.log("There was an error")
    console.log(err)
  funcflow(steps, {errHandler: errHandler, cb: cb, user: user}, last)

putReminderForUser = (reminder, user, success, failure) ->
  steps = [
    (step, err) ->
      if err then step.errHandler(err); return
      console.log("Putting reminder: " + step.reminder)
      step.next()
    (step, err) ->
      if err then step.errHandler(err); return
      step.reminder.user_id = step.user.id
      step.next()
    (step, err) ->
      if err then step.errHandler(err); return
      check(reminder.message,"Message was blank").notEmpty()
      check(reminder.phone, "Phone number was blank").len(7,64)
      step.next()
    (step) ->
      reminder.times = reminder.times.filter (time) ->
        if !time.frequency
            return false
        return true
      step.next()
    (step, err) ->
      if err then step.errHandler(err); return
      process_times = (time, cb) ->
        substeps = [
            (substep, err) ->
              if err then substep.errHandler(err); return
              substep.time.start = substep.time.start * 60 * 60 # seconds since midnight
              substep.next()
            (substep, err) ->
              if err then substep.errHandler(err); return
              substep.time.end = substep.time.end * 60 * 60
              substep.next()
            (substep, err) ->
              if err then substep.errHandler(err); return
              substep.time.days = (x in substep.time.days for x in ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
              d = 0
              while substep.time.days.length > 0
                d *= 2
                d += substep.time.days.pop()
              substep.time.days = d
              substep.next()
            (substep, err) ->
              if err then step.errHandler(err); return
              check(substep.time.frequency, "Please enter a number for frequency").notEmpty().isDecimal()
              substep.next()
            (substep, err) ->
              if err then step.errHandler(err); return
              substep.next()
        ]
        funcflow(substeps, {time:time, errHandler: step.errHandler}, cb)
      for time in reminder.times
        if time.frequency != ""
          process_times time, step.spawn()
      step.next()
    (step, err) ->
      if err then step.errHandler(err); return
      step.next()
  ]
   
  errHandler = (err) ->
    console.log("There was an error")
    if err?.message
      err = err.message
    console.log(err)
    failure(err)
  last = (step) ->
    trans = transaction.createSaveReminderTran(step.reminder)
    transaction.runTran(trans, success)
  funcflow(steps, {errHandler: errHandler, user: user, reminder: reminder}, last)

exports.scheduled = (req, res, data) ->
  user = req.user.getUser()
  getRemindersForUser(user, (reminders) ->
    for r in reminders
      r.times.push(emptyTime)
    reminders.push(emptyReminder)
    res.render('scheduled.ect', common.extend({
      req:req
      page: 'Scheduled'
      daysOfWeek: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
      beginTimesOfDay: common.timesOfDay[...-1]
      endTimesOfDay: common.timesOfDay[1..]
      defaultPhone: "+1 (555) 555-5555"
      reminders: reminders
    }, data)))

exports.scheduledPost = (req, res) ->
  req.user.getUser()
  console.log(req.body)
  json = JSON.parse(req.body.json)
  for reminder in json.reminders
    putReminderForUser(reminder, user, () ->
      exports.scheduled(req, res, {successMsg: "Successfully updated."})
    (errMsg) ->
      exports.scheduled(req, res, {errorMsg: errMsg}))
