transaction = require('../database/trans')
common = require('../common')
funcflow = require('funcflow')

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
  common.getUser(req).success (user) ->
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
  common.getUser(req).success (user) ->
    console.log(req.body)
    json = JSON.parse(req.body.json)
    for reminder in json.reminders
      putReminderForUser(reminder, user, () ->
        exports.scheduled(req, res, {successMsg: "Successfully updated."})
      (errMsg) ->
        exports.scheduled(req, res, {errorMsg: errMsg}))
