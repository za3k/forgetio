### example of reminder for this query
{
    id:undefined # new number
    numer:"+15554561738"
    UserId:3
    confirmedDate:null # not confirmed
}
###

model = require('./model')
common = require('../common')
logger = common.logger
funcflow = require('funcflow')
exports.createTran = (phone)->
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
        run:(step)->step.next(phone)
    }]
    
exports.runTran = (steps, callback=()->)->
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
        funcflow(createRollbackStep(steps[i]) for i in [currStep-1..0] by 1, callback)
    createRunStep = (index, stepFunc)->
        (step,err)->
            if err then rollback(err)
            currStep = index
            if stepFunc.run?
                res = stepFunc.run.apply(stepFunc, arguments)
                if res? && res.on?
                    res.on("success", step.next)
                    res.on("error",(err)->throw err)
            else
                step.next()
    funcflow((createRunStep(i, steps[i]) for i in [0...steps.length]), {catchExceptions:false}, callback)
    
t = exports.createTran({UserId:0, number:'+5559484958'})
exports.runTran(t)
        