check = require('validator').check
common = require('../common')
model = require('../database/model')
ctrl = require('ctrl')
sanitize = require('validator').sanitize
stripe = require('stripe')('sk_test_cnma6aLXwZVj28xddzaby1fL')
#stripe = require('stripe')('sk_live_fNeG2hpEa8Du0Dc5pYarIHT0')
routes = require('./all')

exports.account = (req, res, data) ->
  user = req.user.getUser()
  common.logger("exports.account before getCommunication")
  model.getCommunication user, (err, result) ->
    common.logger("exports.account getCommunication returned")
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

exports.paymentPost = (req, res) ->
    json = req.body
    user = req.user.getUser()
    steps = [(step)->
      common.logger.debug("Make sure form is validly formatted")
      stripe_token = json.stripeToken
      if not stripe_token? or stripe_token == ""
        common.logger.error("Stripe token missing on payment form")
        throw "There was a server error with the form submission."
      # Make sure credits are validly formatted as an integer >= 50
      check(json.credits).isInt().min(50).max(100000)
      step.data.credits = sanitize(json.credits).toInt()
      step.data.stripeToken = json.stripeToken
      step.next()
    (step)->
      # Calculate the correct price
      common.logger.debug("Calculate the correct price")
      step.data.cost = step.data.credits * 2
      step.next()
    (step)->
      #Record the token in the database before trying to run the charge
      common.logger.debug("Record the token in the database before trying to run the charge")
      model.createUserPayment {
        credit: step.data.credits
        money: step.data.cost
        stripe_token: step.data.stripeToken
      }, ((userPayment, err) ->
        step.data.createUserPaymentErr = err
        step.data.userPayment = userPayment
        step.next()
      )
    (step)->
      if step.data.createUserPaymentErr?
        common.logger.error(step.data.createUserPaymentErr)
        throw "There was a server error with the form submission."
      step.next()
    (step)->
      # Run the charge
      common.logger.debug("Run the charge")
      charge = {
        amount: step.data.cost
        currency: "usd"
        card: step.data.stripeToken
        description: "Buying " + step.data.credits + " credits for account: " + user.id + " (email: " + user.email + ")"
      }
      stripe.charges.create charge, (err, response) ->
        step.data.stripeErr = err
        step.data.response = response
        step.next()
    (step) ->
      err = step.data.stripeErr
      if err?
        throw err
      step.next()
    (step) ->
      # Make sure the charge succeeded
      common.logger.debug("Make sure the charge succeded")
      if not step.data.response.paid or not step.data.response.paid==true
        common.logger.error("Payment declined")
        throw "Payment on this credit card was declined for the given amount."
      step.data.fee = step.data.response.fee
      step.data.id = step.data.response.id
      step.next()
    (step)->
      # Update the charge entry in the database
      common.logger.debug("Update the charge entry in the database")
      userUpdated = step.spawn()
      chargeUpdated = step.spawn()

      model.updateUser user, {
        credit: user.credit + step.data.credits
      }, ((updatedUser, err) ->
        if err?
          step.data.updateUserErr = err
        userUpdated()
      )

      model.updateUserPayment step.data.userPayment, {
        stripe_fee: step.data.fee
        stripe_charge: step.data.id
      },((updatedCharge, err) ->
        if err?
          step.data.updateChargeErr = err
        chargeUpdated()
      ) 
      step.next()
    (step)->
      paymentErrMsg = "There was a problem procesing the payment. We received the payment but there was a problem crediting your account. Please email tech support at <a mailto:\"vanceza@gmail.com\">vanceza@gmail.com</a>"
      if step.data.updateUserErr?
        common.logger.error(step.data.updateUserErr)
        throw paymentErrMsg
      if step.data.updateChargeErr?
        common.logger.error(step.data.updateChargeErr)
        throw paymentErrMsg
      step.next()
    ]
    errorHandler = (step, error)->
      common.logger.debug("errorHandler")
      json.errorMsg =  if error?.message? then error.message else error.toString()
      common.logger.error(json.errorMsg)
      routes.account(req, res, json)
    afterSuccessfulPayment = (step)->
      json.successMsg = step.data.credits + " credits were successfully added to your account."
      routes.account(req, res, json)
    ctrl(steps, {errorHandler:errorHandler}, afterSuccessfulPayment)
