debugger;
check = require('validator').check
common = require('../common')
model = require('../database/model')
ctrl = require('ctrl')
sanitize = require('validator').sanitize

exports.account = (req, res, data) ->
  user = req.user.getUser()
  common.logger.debug(user)
  common.logger.debug("exports.account before getCommunication")
  model.getCommunication user, (err, result) ->
    common.logger.debug("exports.account getCommunication returned")
    common.logger.debug(user?.email)
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
        timezone: user.timezone_id
        name: user.name
        credits: user.credit
        email: user.email
        lowerTimeEstimate: user.credit / 10
        upperTimeEstimate: user.credit / 5
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
  debugger;
  json = req.body
  user = req.user.getUser()
  steps = [(step)->
    if json.timezone == user.timezone_id
      exports.account(req, res)
    check(json.timezone, 'Timezone is invalid!').isInt()
    step.data.timezone = sanitize(json.timezone).toInt()
    step.next()
  (step)->
    user.timezone_id =  step.data.timezone
    model.saveUser user, (res, err) ->
      step.data.saveErr = err
      step.next()
  (step)->
    if step.data.saveErr?
      common.logger.error("Error saving user's timezone", err)
      throw {message:"There was a server error!"}
    step.next()
  (step)->
    exports.account(req, res)
    step.next()
  ]
  errorHandler = (error)->
    json.errorMsg =  if error?.message? then error.message else error.toString()
    common.logger.error(json.errorMsg)
    exports.account(req, res, json)
  ctrl(steps, {errorHandler:errorHandler},()->{})
