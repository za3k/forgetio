check = require('validator').check
common = require('../common')
model = require('../database/model')
funcflow = require('funcflow')
sanitize = require('validator').sanitize

exports.account = (req, res, data) ->
  user = req.user.getUser()
  model.getCommunication u, (err, result) ->
    if err
      common.logger.error err
    all = common._.pluck(result, 'server_received')
    result_present = common._.compact(all)
    res.render('account.ect', common.extend({
      page: 'Account'
      req:req
      user: {
        messagesReceived: result_present.length
        messagesSent: all.length - result_present.length
        timezone: u.timezone_id
        name: u.name
        credits: u.credit
        email: u.email
        lowerTimeEstimate: u.credit / 10
        upperTimeEstimate: u.credit / 5
      }
      warningLevel: (daysLeft) ->
          if daysLeft < 1
              "alert alert-error"
          else if 1 <= daysLeft < 7
              "alert"
          else
              "alert alert-info"
    }, data))
exports.accountPost = (req, res) ->
    json = req.body
    user = req.user.getUser()
    steps = [(step, err)->
      if err then step.errorHandler(err); return
      if json.timezone == user.timezone_id
        exports.account(req, res)
      check(json.timezone, 'Timezone is invalid!').isInt()
      step.next(sanitize(json.timezone).toInt())
    (step, err, timezone)->
      if err then step.errorHandler(err); return
      user.timezone_id =  timezone
      user.save().success(step.next).failure((err)->
        common.logger.error("Error saving user's timezone", err)
        step.errorHandler({message:"There was a server error!"}))
    (step, err)->
      if err then step.errorHandler(err); return
      exports.account(req, res)
      step.next()
    ]
    errorHandler = (error)->
      json.errorMsg =  if error?.message? then error.message else error.toString()
      common.logger.error(json.errorMsg)
      exports.account(req, res, json)
    funcflow(steps, {errorHandler:errorHandler},()->{})
