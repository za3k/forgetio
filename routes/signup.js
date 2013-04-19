// Generated by CoffeeScript 1.6.2
(function() {
  var check, common, ctrl, model, sanitize, shared, signup;

  check = require('validator').check;

  common = require('../common');

  model = require('../database/model');

  ctrl = require('ctrl');

  sanitize = require('validator').sanitize;

  shared = common.shared;

  signup = function(req, res, data) {
    if (data == null) {
      data = {};
    }
    return res.render('signup.ect', common.extend({
      page: 'Signup',
      req: req,
      config: req.config
    }, data));
  };

  exports.signup = function(req, res) {
    return signup(req, res);
  };

  exports.signupPost = function(req, res) {
    var errorHandler, json, loginSuccess, steps;

    json = req.body;
    steps = [
      function(step) {
        json.timezone_id = json.TimeZoneId;
        delete json.TimeZoneId;
        check(json.name, 'Name is required!').len(4, 255);
        check(json.timezone_id, 'Timezone is invalid!').isInt();
        check(json.email, 'Email is invalid!').len(4, 255).isEmail();
        check(json.password, 'Password must be at least 8 characters!').len(8, 255);
        json.email = sanitize(json.email.toLowerCase()).trim();
        json.password = require('password-hash').generate(sanitize(json.password.toLowerCase()).trim());
        json.name = sanitize(json.name).trim();
        json.timezone_id = sanitize(json.timezone_id).toInt();
        return step.next();
      }, function(step) {
        return model.User.find({
          where: {
            email: json.email
          }
        }).success(function(user) {
          step.data.user = user;
          return step.next();
        }).error(function(err) {
          common.logger.error("Error retrieving user by email", err);
          throw {
            message: "There was a server error!"
          };
        });
      }, function(step) {
        var user;

        if (typeof user !== "undefined" && user !== null) {
          throw {
            message: "A user with that email already exists!"
          };
        }
        user = model.User.build(json);
        console.dir(user);
        return user.save().success(step.next).error(function(err) {
          common.logger.error("Error saving user", err);
          throw {
            message: "There was a server error!"
          };
        });
      }, function(step) {
        req.session.UserId = step.data.user.id;
        return step.next();
      }
    ];
    errorHandler = function(error) {
      delete json.password;
      json.errorMsg = (error != null ? error.message : void 0) != null ? error.message : error.toString();
      return signup(req, res, json);
    };
    loginSuccess = function() {
      return res.redirect('/scheduled.html');
    };
    return ctrl(steps, {
      errorHandler: errorHandler
    }, loginSuccess);
  };

}).call(this);
