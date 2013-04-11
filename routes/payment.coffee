check = require('validator').check
common = require('../common')
model = require('../database/model')
funcflow = require('funcflow')
sanitize = require('validator').sanitize
stripe = require('stripe')('sk_live_fNeG2hpEa8Du0Dc5pYarIHT0')
routes = require('./all')

exports.account = (req, res, data) ->
  common.getUser(req).success((u) ->
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
  ).failure((err) ->
      console.log(err)
      res.render('account.ect', {
        errMsg: "User not found. Please log in."
      })
    )

exports.paymentPost = (req, res) ->
    json = req.body
    steps = [(step, err)->
      if err then step.errorHandler(err) ; return
      common.getUser(req).success((user)->
        step.user = user
        step.next()
      ).failure((err)->step.raise(err))
    (step, err)->
      if err then step.errorHandler(err) ; return
      stripe_token = json.stripeToken
      if not stripe_token? or stripe_token == ""
        common.logger.error("Stripe token missing on payment form")
        step.errorHandler("There was a server error with the form submission.");return
      # Make sure credits are validly formatted as an integer >= 50
      check(json.credits).isInt().min(50).max(100000)
      step.credits = sanitize(json.credits).toInt()
      step.stripeToken = json.stripeToken
      step.next()
    (step, err)->
      if err then step.errorHandler(err) ; return
      # Calculate the correct price
      step.cost = step.credits * 2
      step.next()
    (step, err)->
      if err then step.errorHandler(err) ; return
      #TODO: Record the token in the database before trying to run the charge
      model.UserPayment.create({
        credit: step.credit
        money: step.cost
        stripe_token: step.stripeToken
      }).success(step.next).failure((err) ->
        common.logger.error(err)
        step.errorHandler("There was a server error with the form submission.");return
      )
    (step, err, user_payment)->
      if err then step.errorHandler(err) ; return
      step.user_payment = user_payment
      step.next()
    (step, err)->
      if err then step.errorHandler(err) ; return
      # Run the charge
      charge = {
        amount: step.cost
        currency: "usd"
        card: step.stripeToken
        description: "Buying " + step.credits + " credits for account: " + step.user.id + " (email: " + step.user.email + ")"
      }
      stripe.charges.create(charge, step.next)
    (step, err, err2, response) ->
      if err then step.errorHandler(err) ; return
      if err2
        step.errorHandler(err2) ; return
      # Make sure the charge succeeded
      if not response.paid or not response.paid==true
        common.logger.error("Payment declined")
        step.errorHandler("Payment on this credit card was declined for the given amount.")
      step.response = response
      step.next(response.id, response.fee)
    (step, err, id, fee)->
      if err then step.errorHandler(err) ; return
      # Update the charge entry in the database
      onFailure = (err) ->
        common.logger.error(err)
        step.errorHandler("There was a problem procesing the payment. We received the payment but there was a problem crediting your account. Please email tech support at <a mailto:\"vanceza@gmail.com\">vanceza@gmail.com</a>") ; return
      uu = step.spawn()
      uc = step.spawn()
      updateUser = step.user.updateAttributes({
        credit: step.user.credit + step.credits
      }).success(uu).failure(onFailure)

      updateCharge = step.user_payment.updateAttributes({
        stripe_fee: fee
        stripe_charge: id
      }).success(uc).failure(onFailure)

      step.next()
    (step, err)->
      step.next()
    ]
    errorHandler = (error)->
      json.errorMsg =  if error?.message? then error.message else error.toString()
      common.logger.error(json.errorMsg)
      routes.account(req, res, json)
    funcflow steps, {errorHandler:errorHandler},(step, err)->
      json.successMsg = step.credits + " credits were successfully added to your account."
      routes.account(req, res, json)
