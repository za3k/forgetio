childProcess = require 'child_process'
fs = require 'fs'
funcflow = require 'funcflow'
_ = require 'underscore'
flatten = _.flatten
common = require './common'
nconf = common.nconf
logger = common.logger

createDbDropSteps= ()->
    return common.flatten [
        for table in ["users", "reminders", "phones", "reminder_times", "sent_messages", "received_messages", "timezones"]
          do (table) ->
            (step, err)->
              childProcess.exec 'psql notify -c "DROP TABLE ' + table + ' CASCADE;"', (error, stdout, stderr) ->
                console.log("Dropping table " + table + "...")
                console.log(stdout)
                console.log(stderr)
                if error
                  common.logger.error(error)
                step.next()
        (step, err)->
            if err
              common.logger.error(error)
            logger.debug('All tables have been droped!!')
            step.next()
    ]
    
createDbCreateSteps= ()->
    model = require('./database/model')
    return [
        (step, err)->
          childProcess.exec 'python ./database/sql_def.py', (error, stdout, stderr) ->
            console.log(stdout)
            console.log(stderr)
            if error
              common.logger.error(error)
            step.next()
        (step, err)->logger.debug('Created tables!'); step.next()
        (step, err)->require('./database/createTimeZones').run({}, step.next)
        (step, err)->logger.debug('Inserted data!'); step.next()
        (step, err)->logger.debug('Database created!'); step.next()
    ]
    
createCompileCoffeeSteps=(min)->
    createCompileSteps=(filename)->
        return [
            (step, err)->readFile(filename, step.next)
            (step, err, file)->compile(file, step.next)
            (step, err, file)->if min then compress(file, step.next) else step.next(file)
            (step, err, file)->writeFile(filename.replace(".coffee",".js"), file, step.next)
        ]
    return [
        (step, err)->require('glob')("*.coffee",  {cwd:'./public'}, step.next)
        (step, err, er, files)->
            console.log files
            funcflow(common.flatten(createCompileSteps('./public/' + f) for f in files), {catchExceptions:false}, step.next)
    ]
    

job = (name, desc="", steps, callback=(err)->if err? then logger.error(err.stacktrace))->
    task(name, desc, (options)->funcflow(flatten(steps, {catchExceptions:false, "options":options}, callback)))

job 'db:drop', 'drops the database', createDbDropSteps()
job 'db:sync', 'drops and recreates the database', createDbCreateSteps()
job 'build', 'compiles all client side coffee script', createCompileCoffeeSteps(false)
job 'build:min', 'compiles and minifies all client side coffee script', createCompileCoffeeSteps(true)


# util methods
compile = (inputFile, callback) ->
    coffee = require 'coffee-script'
    callback?(coffee.compile(inputFile))

compress = (inputFile, callback) ->
    UglifyJS = require "uglify-js"
    toplevel = UglifyJS.parse(inputFile)
    toplevel.figure_out_scope()
    compressor = UglifyJS.Compressor()
    compressed_ast = toplevel.transform(compressor)
    compressed_ast.figure_out_scope()
    compressed_ast.compute_char_frequency()
    compressed_ast.mangle_names()
    callback?(compressed_ast.print_to_string())
    
readFile = (filename, callback) ->
    data = fs.readFile(filename, 'utf8', (err, data)-> if err then throw err else callback(data))
 
writeFile = (filename, data, callback) ->
    fs.writeFile(filename, data, 'utf8', (err)-> if err then throw err else callback())
