childProcess = require 'child_process'
fs = require 'fs'
funcflow = require 'funcflow'
_ = require 'underscore'
flatten = _.flatten
common = require './common'
nconf = common.nconf
logger = common.logger

createDbDropSteps= ()->
    model = require('./database/model')
    return [
        (step, err)->model.sequelize.drop().success(step.next).error((err)->logger.error(err))
        (step, err)->
            logger.debug('All tables have been droped!!')
            step.next()
    ]
    
createDbCreateSteps= ()->
    model = require('./database/model')
    handle=(emitter, callback)->
        emitter.on("success", callback)
        emitter.on("error", (err)->console.log(err))
    return [
        (step, err)->handle(model.sequelize.sync({force:true}), step.next)
        (step, err)->logger.debug('Created tables!'); step.next()
        (step, err)->handle(model.sequelize.getQueryInterface().removeColumn('Reminders', 'id'), step.next)
        (step, err)->handle(model.sequelize.getQueryInterface().addColumn('Reminders', 'id', {type:model.Sequelize.INTEGER, allowNull:false, autoIncrement:true}), step.next)
        (step, err)->handle(model.sequelize.getQueryInterface().addIndex('Reminders',['id','version'], {indicesType:'UNIQUE'}), step.next)
        (step, err)->logger.debug('Modified tables!'); step.next()
        (step, err)->require('./database/queries/createTimeZones').run({}, step.next)
        (step, err)->logger.debug('Inserted data!'); step.next()
        (step, err)->logger.debug('Database created!'); step.next()
    ]
    

job = (name, desc="", steps, callback=(err)->if err? then logger.error(err.stacktrace))->
    task(name, desc, (options)->funcflow(flatten(steps, {catchExceptions:false, "options":options}, callback)))

job 'db:drop', 'drops the database', createDbDropSteps()
job 'db:sync', 'drops the database', createDbCreateSteps()