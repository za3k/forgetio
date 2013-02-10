model = require('../model')
funcflow = require('funcflow')
### example of how to make a reminder for this query
reminder = model.Reminder.build({
    version:0
    message:'some message'
    enabled:true
})
reminder.times = [
    model.ReminderTime.build({
        start:0 # seconds since 12am... in this case 12am
        end:60*60*8 # seconds since 12am... in this case 8 am
        frequency: 5
        days: 31 # there are utility methods getDays and setDays which make setting this value easier
    })
    model.ReminderTime.build({
        start:60*60*1 # seconds since 12am... in this case 1 am
        end:60*60*8 # seconds since 12am... in this case 8 am
        frequency: 5
        days: 1 # there are utility methods getDays and setDays which make setting this value easier
    })
]
###
exports.run = (reminder, callback)->
    
    