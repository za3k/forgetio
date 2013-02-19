exports.home = (req, res) ->
  res.render('home.ect', { page: 'Home', req:req })
