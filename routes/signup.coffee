check = require('validator').check
common = require('../common')
model = require('../database/model')
ctrl = require('ctrl')
sanitize = require('validator').sanitize
shared = common.shared

signup = (req, res, data={})->
    res.render('signup.ect', common.extend({
        page: 'Signup'
        req:req
        config: req.config}, data))
exports.signup=(req, res)->signup(req,res)
exports.signupPost = (req, res) ->
    json = req.body
    steps = [(step)->
        json.timezone_id = json.TimeZoneId
        delete json.TimeZoneId
        # validate the data
        check(json.name, 'Name is required!').len(4,255)
        check(json.timezone_id, 'Timezone is invalid!').isInt()
        check(json.email, 'Email is invalid!').len(4,255).isEmail()
        check(json.password, 'Password must be at least 8 characters!').len(8,255)
        # sanitize the data
        json.email = sanitize(json.email.toLowerCase()).trim()
        json.password = require('password-hash').generate(sanitize(json.password.toLowerCase()).trim())
        json.name = sanitize(json.name).trim()
        json.timezone_id = sanitize(json.timezone_id).toInt()
        step.next()
    (step)->
        # check if email already exists
        findUserForEmail json.email, (user, err) ->
            if err?
                step.data.findUserErr = err
            step.data.user = user
            step.next()
    (step)->
        if step.data.findUserErr?
            common.logger.error("Error retrieving user by email", step.data.findUserErr)
            throw {message:"There was a server error!"})
        step.next()
    (step)->
        if step.data.user? then throw {message:"A user with that email already exists!"}
        # save the new user!
        user = model.User.build(json)
        model.saveUser user, (savedUser, err) ->
            if err?
                step.data.saveUserErr = err
            step.data.user = savedUser
            step.next()
    (step)->
        if step.data.saveUserErr?
            common.logger.error("Error saving user", step.data.saveUserErr)
            throw {message:"There was a server error!"})
        step.next()
    (step)->
        # log the user in!
        req.session.login step.data.user
        step.next()
    ]
    errorHandler = (error)->
        delete json.password
        json.errorMsg =  if error?.message? then error.message else error.toString()
        signup(req, res, json)
    signupSuccess = ()-> 
        res.redirect('/account.html')
    ctrl(steps, {errorHandler:errorHandler}, signupSuccess)
