childProcess = require 'child_process'
fs = require 'fs'
funcflow = require 'funcflow'
_ = require 'underscore'
flatten = _.flatten
common = require './common'
nconf = common.nconf
logger = common.winston

createDbDropSteps= ()->
    model = require('./database/model')
    return [
        (step, err)->model.sequelize.drop().success(step.next).error((err)->logger.error(err))
        (step, err)->
            console.log('All tables have been droped!!')
            step.next()
    ]
    
createDbCreateSteps= ()->
    model = require('./database/model')
    return [
        (step, err)->model.sequelize.sync().success(step.next).error((err)->logger.error(err))
        (step, err)->require('./database/queries/createTimeZones').run({}, step.next)
        (step, err)->model.sequelize.getQueryInterface().removeColumn('Reminders', 'id'); step.next()
        (step, err)->model.sequelize.getQueryInterface().addIndex('Reminders',['Id','Version'], {indicesType:'UNIQUE'}); step.next()
    ]
    

job = (name, desc="", steps, callback=(err)->if err? then logger.log(err))->
    task(name, desc, (options)->funcflow(flatten(steps, {catchExceptions:false, "options":options}, callback)))

job 'db:drop', 'drops the database', createDbDropSteps()
job 'db:sync', 'drops the database', createDbCreateSteps()