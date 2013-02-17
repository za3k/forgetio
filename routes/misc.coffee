#!/usr/bin/env coffee

exports.home = (req, res) ->
  console.log(req.config)
  res.render('home.ect', { page: 'Home', req:req })

exports.results = (req, res) ->
  res.render('results.ect', { page: 'Results', req:req })
