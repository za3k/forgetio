
/*
 * GET home page.
 */

exports.index = function(req, res){
  res.render('home.ect', { page: 'Home' });
};

exports.account = function(req, res){
  res.render('account.ect', { page: 'Account' });
};

exports.scheduled = function(req, res){
  res.render('scheduled.ect', { page: 'Scheduled' });
};

exports.results = function(req, res){
  res.render('results.ect', { page: 'Results' });
};

exports.signup = function(req, res){
  res.render('signup.ect', { page: 'Signup' });
};
