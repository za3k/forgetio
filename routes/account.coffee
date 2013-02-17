check = require('validator').check
common = require('../common')
model = require('../database/model')
funcflow = require('funcflow')
sanitize = require('validator').sanitize

exports.account = (req, res, data) ->
  common.getUser(req).success((u) ->
      res.render('account.ect', common.extend({
        page: 'Account'
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
      common.getUser(req).success((user)->
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
