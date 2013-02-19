common = require '../common'
model = require '../database/model'

exports.results = (req, res) ->
  common.getUser(req).success (user) ->
    model.getCommunication user, (err, result) ->
      if err
        common.logger.error(err)
      reminders = []
      for reminder_id, lines of common._.groupBy(result, 'reminder_id')
        reminder = {
          text: lines[0].message
          replies: []
        }
        for line in lines
          if line.server_received
            reminder.replies.push({
              date: line.scheduled
              reply: {text: line.body, time: line.server_received}
            })
          else
            reminder.replies.push({
              date: line.scheduled
              reply: null
            })
        reminders.push(reminder)
      res.render('results.ect', {
        page: 'Results'
        req:req
        reminders: reminders
      })
