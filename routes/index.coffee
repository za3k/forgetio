#!/usr/bin/env coffee
model = require('../database/model')
shared = {}
model.TimeZone.findAll({order: 'id ASC'}).success((db_times) ->
    timezones = (db_time.values for db_time in db_times)
    
    shared.timezones = timezones
)

exports.index = (req, res) ->
  res.render('home.ect', { page: 'Home' })

exports.account = (req, res) ->
  res.render('account.ect', {
    page: 'Account'
    timezones: shared.timezones
    offset_formatter: (offset) ->
        if offset == 0
            "" 
        else if (offset % 1) == 0
            hours = offset
            minutes = "00"
            "(UTC #{ hours }:#{ minutes }) "
        else
            hours = Math.floor(offset) if offset > 0
            hours = Math.ceil(offset) if offset < 0
            minutes = "30"
            "(UTC #{ hours }:#{ minutes }) "
  })

exports.signup = (req, res) ->
  res.render('signup.ect', { page: 'Signup' })

exports.scheduled = (req, res) ->
  res.render('scheduled.ect', { page: 'Scheduled' })

exports.results = (req, res) ->
  res.render('results.ect', { page: 'Results' })
