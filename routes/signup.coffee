check = require('validator').check
common = require('../common')
model = require('../database/model')
funcflow = require('funcflow')
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
        model.User.find({where:{email:json.email}})
            .success((user) ->
                step.data.user = user
                step.next()
            ).error((err)->
                common.logger.error("Error retrieving user by email", err)
                throw {message:"There was a server error!"})
    (step)->
        if user? then throw {message:"A user with that email already exists!"}
        # save the new user!
        user = model.User.build(json)
        console.dir(user)
        user.save()
            .success(step.next)
            .error((err)->
                common.logger.error("Error saving user", err)
                throw {message:"There was a server error!"})
    (step)->
        # log the user in!
        req.session.UserId = step.data.user.id
        step.next()
    ]
    errorHandler = (error)->
        delete json.password
        json.errorMsg =  if error?.message? then error.message else error.toString()
        signup(req, res, json)
    loginSuccess = ()-> 
        res.redirect('/scheduled.html')
    ctrl(steps, {errorHandler:errorHandler}, loginSuccess)
