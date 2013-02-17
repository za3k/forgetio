check = require('validator').check
common = require('../common')
model = require('../database/model')
funcflow = require('funcflow')
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
    steps = [(step,err)->
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
    (step,err)->
        if err then step.errorHandler(err); return
        # check if email already exists
        model.User.find({where:{email:json.email}})
            .success(step.next)
            .error((err)->
                common.logger.error("Error retrieving user by email", err)
                step.errorHandler({message:"There was a server error!"}))
    (step,err,user)->
        if user? then step.errorHandler({message:"A user with that email already exists!"}); return
        # save the new user!
        user = model.User.build(json)
        console.dir(user)
        user.save()
            .success(()->step.next(user))
            .error((err)->
                common.logger.error("Error saving user", err)
                step.errorHandler({message:"There was a server error!"}))
    (step,err,user)->
        # log the user in!
        req.session.UserId = user.id
        step.next()
    ]
    errorHandler = (error)->
        delete json.password
        json.errorMsg =  if error?.message? then error.message else error.toString()
        signup(req, res, json)
    funcflow(steps, {errorHandler:errorHandler},()->res.redirect('/scheduled.html'))
