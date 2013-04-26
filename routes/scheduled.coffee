transaction = require('../database/trans')
common = require('../common')
check = require('validator').check
sanitize = require('validator').sanitize
ctrl = require('ctrl')

emptyTime = {
  enabled: false
  days: []
}

emptyReminder = {
  times: [emptyTime, emptyTime]
}

processReminder = (r, errorHandler, cb) ->
  reminder = {
    message: r.message
    id: r.id
    version: r.version
    parentId: r.parentId
    times: []
    error: r.error
  }
  reminder_steps = [
    (step) ->
      step.data.reminder = reminder
      step.next()
    (step) ->
      time_cb = step.spawn()
      phone_cb = step.spawn()
      r.getTimes().success((ts) ->
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
          step.data.reminder.times.push(time)
        time_cb()
      ).failure((err) ->
        step.data.timeErr = err
        time_cb()
      )

      r.getPhone().success((p) ->
        step.data.reminder.phone = p.number
        phone_cb()
      ).failure((err) ->
        step.data.phoneErr = err
        phone_cb()
      )

      step.next()
    (step) ->
      if step.data.timeErr?
        throw step.data.timeErr
      if step.data.phoneErr?
        throw step.data.phoneErr
      step.next()
  ]
  afterSuccessfulProcessing = (step) ->
    cb(step.data.reminder)
  ctrl(reminder_steps, {errorHandler: errorHandler}, afterSuccessfulProcessing)

getRemindersForUser = (user, final_cb) ->
  errorHandler = (step, error) ->
    console.log("There was an error")
    console.log(error)
  steps = [
    (step) ->
      user.getReminders().success( (reminders) ->
        step.data.reminders = reminders
        step.next()
      ).failure((err)->
        step.data.getReminderErr = err
        step.next()
      )
    (step) ->
      if step.data.getReminderErr?
        throw step.data.getReminderErr
      step.next()
    (step) ->
      reminders = step.data.reminders
      step.data.reminders = []
      for r in reminders
        cb = step.spawn()
        processReminder r, errorHandler, (reminder) ->
          step.data.reminders.push(reminder)
          cb()
      step.next()
    (step) ->
      common.logger.debug(JSON.stringify(step.data))
      for r in step.data.reminders
        if !r.parent_id?
          r.parentId = r.id
      step.data.reminders = step.data.reminders.filter (reminder) ->
        for r in step.data.reminders
          if r.parent_id == reminder.parent_id and r.version > reminder.version
            return false
        return true
      step.next()
  ]
  last = (step) ->
    final_cb(step.data.reminders)
  ctrl(steps, {errorHandler: errorHandler}, last)

processTime = (time) ->
  time.start = time.start * 60 * 60 # seconds since midnight
  time.end = time.end * 60 * 60
  time.days = (x in time.days for x in ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
  d = 0
  while time.days.length > 0
    d *= 2
    d += time.days.pop()
  time.days = d
  check(time.frequency, "Please enter a number for frequency").notEmpty().isDecimal()
  time

putReminderForUser = (reminder, user, success, failure) ->
  errorHandler = (step, err) ->
    common.logger.error("There was an error")
    if err?.message
      err = err.message
    common.logger.error(err)
    failure(err)

  steps = [
    (step) ->
      common.logger.debug("Putting reminder: " + reminder)
      step.next()
    (step) ->
      reminder.user_id = user.id
      step.next()
    (step) ->
      check(reminder.message,"Message was blank").notEmpty()
      check(reminder.phone, "Phone number was blank").len(7,64)
      step.next()
    (step) ->
      common.logger.debug("Stripping out invalid times")
      reminder.times = reminder.times.filter (time) ->
        if !time.frequency
            return false
        return true
      step.next()
    (step) ->
      for time in reminder.times
        if time.frequency != ""
          processTime time
      step.next()
  ]
  last = (step) ->
    trans = transaction.createSaveReminderTran(reminder)
    transaction.runTran(trans, success)
  ctrl(steps, {errorHandler: errorHandler}, last)

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
  user = req.user.getUser()
  console.log(req.body)
  json = JSON.parse(req.body.json)
  for reminder in json.reminders
    putReminderForUser(reminder, user, () ->
      exports.scheduled(req, res, {successMsg: "Successfully updated."})
    (errMsg) ->
      exports.scheduled(req, res, {errorMsg: errMsg}))
bv