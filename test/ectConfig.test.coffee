assert = require("pretty-assert")
ectConfig = require("../ectConfig")

#TODO: figure out a way to move async setup to the fixture and out of the test

describe 'ectConfig', ->
	describe '.timezones', ->
			it 'should contain only valid values', (done) ->
				ectConfig.timezones (timezones) ->
					debugger;
					for o in timezones
						assert.defined o.id
					done()
				console.log("hi")