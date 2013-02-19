model = require('./model')
common = require('../common')
logger = common.logger
funcflow = require('funcflow')

### example of reminder for this query
{
    UserId:0
    version:0
    message:'some message'
    enabled:true
    id:undefined   # it's a new record
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
exports.createSaveReminderTran = (reminder)->
    if reminder.id?
        reminder.version++
        if not reminder.parent_id? then reminder.parent_id = reminder.id
        delete reminder.id
    savedReminder = null
    createTimeStep = (time)->
        return {
            errMsg:"Could not create ReminderTime"
            run:(step)->
                @time = model.ReminderTime.build(time)
                @time.reminder_id = savedReminder.id
                @time.save()
            rollback:(step)->@time.destroy()
        }
    removeTimeStep = (time)->
        return {
            errMsg:"Could not delete ReminderTime"
            run:(step)->
                model.ReminderTime.find({where:{id:time.id}}).success((time) ->
                    @time = time
                    @time.deleted = true
                    @time.save())
            rollback:(step)->
                @time.deleted = false # simplistic but hopefully this works
                @time.save()
        }
    return common.flatten([{
        errMsg:"Call to see if user owns reminder failed!"
        run:(step,err)->
            if not reminder.parent_id? then step.next(); return
            model.Reminder.find({where:{id:reminder.parent_id}})
    },{
        run:(step,err, rem)->
            if reminder.parent_id? and (not rem? or rem.UserId != reminder.UserId)
                console.log reminder.parent_id
                throw "User does not own the reminder they are trying to save!"
            if rem?.parent_id?
                reminder.parent_id = rem.parent_id # Point to the root, not the immediate parent
            step.next()
    },exports.createSavePhoneTran({number:reminder.phone}),{
        errMsg:"Could not save Reminder"
        run:(step,err,phone)->
            savedReminder = model.Reminder.build(if reminder.values? then reminder.values else reminder)
            savedReminder.phone_id = phone.id
            delete savedReminder.phone
            delete savedReminder.times
            savedReminder.save()
        rollback:(step)->savedReminder.destroy()
    },(createTimeStep(t) for t in reminder.times),{
        run:(step,err)->
            step.next(savedReminder)
    }])

### example of phone number for this query
{
    id:undefined # new number
    number:"+15554561738"
    UserId:3
    confirmedDate:null # not confirmed
}
###
exports.createSavePhoneTran = (phone)->
    if phone.values? then phone = phone.values
    return [{
        errMsg:"Call to see if phone number already exists failed!"
        run:(step)->model.Phone.find({ where: { number:phone.number }})
    },{
        run:(step, err, p)->
            if p then phone = common.extend(p.values, phone)
            step.next()
    },{
        errMsg:"Could not save phone number"
        run:(step)->
            phone = model.Phone.build(phone)
            phone.isNewRecord = not phone.id?
            phone.save()
    },{
        run:(step, error, p)->step.next(p)
    }]
    
exports.runTran = (steps, callback=()->)->
    steps.push (step,err)->step.next() # add one final step so we do not have to wrap callback
    currStep = 0
    createRollbackStep = (stepFunc)->
        (step,err)->
            if err then logger.error("Error rolling back. Message:'#{steps[currStep].errMsg}'", err)
            if stepFunc.rollback?
                res = stepFunc.rollback.apply(stepFunc, arguments)
                if res? && res.on?
                    res.on("success", step.next)
                    res.on("error",(err)->throw err)
            else
                step.next()
    rollback = (err)->
        logger.error("Error in transaction... rolling back. Message:'#{steps[currStep].errMsg}'", err)
        funcflow(createRollbackStep(steps[i]) for i in [currStep-1..0], (step, e)->callback(step, err))
    createRunStep = (index, stepFunc)->
        (step,err)->
            if err
                rollback(err)
                return
            currStep = index
            if stepFunc.run?
                res = stepFunc.run.apply(stepFunc, arguments)
                if res? && res.on?
                    res.on("success", step.next)
                    res.on("error",(err)->throw err)
            else
                step.next()
    funcflow((createRunStep(i, steps[i]) for i in [0...steps.length]),{}, callback)
