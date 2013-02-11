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
  res.render('scheduled.ect', { 
    page: 'Scheduled' 
    daysOfWeek: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    timesOfDay: [
        {
         value:7
         text:"7:00am"
        },
        {
         value:9
         text:"9:00am"
        },
        {
         value:17.5
         text:"5:30pm"
        },
        {
         value:21
         text:"9:00pm"
        },
        {
         value:24
         text:"Midnight"
        }
    ]
    reminders: [
        {
         message: "How happy are you right now on a scale of 0-10?"
         times: [
             {
              frequency: 5
              start: 7
              end: 9
              days: ["Tue","Wed","Thu","Fri","Sat","Sun"]
              enabled: true
             },
             {
              frequency: 5
              start: 17.5
              end: 24
              days: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
              enabled: false
             }
         ]
        },
        {
         message: "How curious are you right now on a scale of 0-10?"
         times: [
             {
              frequency: 5
              start: 7
              end: 9
              days: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
              enabled: false
             },
             {
              frequency: 5
              start: 17.5
              end: 21
              days: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
              enabled: false
             }
         ]
        }
    ]
  })

exports.results = (req, res) ->
  res.render('results.ect', { page: 'Results' })
