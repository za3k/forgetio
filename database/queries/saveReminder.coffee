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
reminder.phone='+15553121238'
###
### example of reminder for this query
{
    version:0
    message:'some message'
    enabled:true
    id:undefined   # its a new recode
    phone:'+15553121238'
    times:[{
        start:0 # seconds since 12am... in this case 12am
        end:60*60*8 # seconds since 12am... in this case 8 am
        frequency: 5
        days: 31 # there are utility methods getDays and setDays on model.ReminderTime which make setting this value easier
    },{
        start:60*60*1 # seconds since 12am... in this case 1 am
        end:60*60*8 # seconds since 12am... in this case 8 am
        frequency: 5
        days: 31 # there are utility methods getDays and setDays on model.ReminderTime which make setting this value easier
    }]
}
###

model = require('../model')
funcflow = require('funcflow')
common = require('../../common')
logger = common.logger

exports.run = (reminder, callback)->
    steps = []
    steps.push (step,err)->model.Reminder.build(reminder)
    for time in reminder.times
        steps.push model.Reminder.build(time)
    
    reminder = model.Reminder.build(reminder)
    
createRunSteps = (reminderJson)->
    # update version number
    if not reminder.id?
        reminder.version++
        reminder.parentId = reminder.id
        reminder.id = undefined

    # some util function and shared vars
    reminder = null
    createTimeStep = (time)->
        time.ReminderId = reminder.id
        return {
            errMsg:"Could not create ReminderTime"
            run:(step)->
                @time = model.ReminderTime.build(time)
                @time.save()
            rollback:(step)->@time.destroy()
        }
    
    # make actual steps
    steps = common.flatten([{
        errMsg:"Could not save Reminder"
        run:(step)->
            reminder = model.Reminder.build(reminderJson)
            reminder.save()
        rollback:(step)->reminder.destroy()
    },(createTimeStep(t) for t in reminderJson.times)])
    
    # add wrapper around steps
        if not reminder.id? then reminder.version++
    handler = (emmiter, callback)->
        emitter.on("success", callback)
        emitter.on("error", (err)->logger.(err))
    
    