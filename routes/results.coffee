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
          id: reminder_id
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

exports.csvExport = (req, res) ->
  common.getUser(req).success (user) ->
    model.getCommunication user, (err, result) ->
      if err
        common.logger.error(err)
      lines = result
      if req.params.id
        lines = common._.filter lines, (x) -> x.reminder_id.toString() == req.params.id
        console.log(lines)
      if (not req.params.id and lines) or (req.params.id and lines and lines.length > 0)
        res.render('csv.results.ect', {
          req: req
          lines: lines
        })
