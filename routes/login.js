// Generated by CoffeeScript 1.6.2
(function() {
  var common, ctrl, model, sanitize;

  common = require('../common');

  ctrl = require('ctrl');

  model = require('../database/model');

  sanitize = require('validator').sanitize;

  exports.login = function(req, res, data) {
    return res.render('home.ect', common.extend({
      page: 'Login',
      req: req
    }, data));
  };

  exports.loginPost = function(req, res) {
    var afterSuccessfulLogin, errorHandler, json, steps;

    json = req.body;
    console.log(json != null ? json.email : void 0);
    steps = [
      function(step) {
        console.log("Step 1");
        if ((json.email == null) || json.email === "") {
          throw "Please include an email address";
        }
        if ((json.password == null) || json.password === "") {
          throw "Please include a password";
        }
        return step.next();
      }, function(step) {
        return model.User.find({
          where: {
            email: json.email
          }
        }).success(function(user) {
          step.data.user = user;
          return step.next();
        }).failure(function(err) {
          common.logger.error(err);
          throw "There was a server error";
        });
      }, function(step) {
        if (step.data.user == null) {
          common.logger.info("Invalid user");
          throw "Invalid username or password.";
        }
        if (step.data.user.email !== json.email) {
          common.logger.error("Returned user had the wrong email");
          throw "There was an error on the server.";
        }
        return step.next();
      }, function(step) {
        if (!require('password-hash').verify(sanitize(json.password.toLowerCase()).trim(), step.data.user.password)) {
          common.logger.info("Invalid password");
          throw "Invalid username or password.";
        }
        return step.next();
      }, function(step) {
        req.user.login(step.data.user);
        return step.next();
      }
    ];
    errorHandler = function(step, error) {
      json.errorMsg = (error != null ? error.message : void 0) != null ? error != null ? error.message : void 0 : error.toString();
      common.logger.error(json.errorMsg);
      delete json.password;
      return exports.login(req, res, json);
    };
    afterSuccessfulLogin = function() {
      return res.redirect('/account.html');
    };
    return ctrl(steps, {
      errorHandler: errorHandler
    }, afterSuccessfulLogin);
  };

  exports.ensureLogin = function(req, res, next) {
    if (req.user.loggedIn()) {
      return next();
    } else {
      return res.redirect('/login.html');
    }
  };

  exports.logout = function(req, res) {
    req.user.logout();
    return res.redirect('/login.html');
  };

}).call(this);