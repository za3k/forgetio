tzs = undefined
delay = (ms, func) -> setTimeout func, ms
module.exports.timezones = (cb) ->
	if tzs
		return tzs
	else
		model = require('./database/model')
		common = require('./common')

		delay 100, -> # Get around mutal dep (model -> common -> timezones -> model)
			debugger;
			model.findAllTimezones (db_times, err) ->
			    debugger;
			    if err
			        common.logger.error("Couldn't load timezones")
			    timezones = ({
			        id: db_time.id
			        text: offsetDisplayName db_time.offset, db_time.text
			    } for db_time in db_times)
			    tzs = timezones
			    if cb
			    	cb(tzs, err)

offsetDisplayName = (offset, text) ->
    if offset == 0
        text
    else
        {hours, minutes} = offsetToHoursAndMinutes offset
        if minutes < 10
            minutes = "0#{minutes}"
        "(UTC #{ hours }:#{ minutes }) #{ text }"

offsetToHoursAndMinutes = (offset) ->
    if offset == 0
        {
            hours: 0
            minutes: 0
        }
    else if (offset % 3600) == 0
        {
            hours: offset / 3600
            minutes: 0
        }
    else
        hours = Math.floor(offset / 3600) if offset > 0
        hours = Math.ceil(offset / 3600) if offset < 0
        {
            hours: hours
            minutes: Math.floor(Math.abs((offset % 3600) / 60))
        }
