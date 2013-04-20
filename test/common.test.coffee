assert = require("pretty-assert")
common = require("../common")

describe 'Common', ->
	describe '.timesOfDay()', ->
		it 'should have 25 options', ->			
			assert.equal(25, common.timesOfDay.length)
		it 'should contain only valid values', ->
			for o in common.timesOfDay
				assert.finite o.value
				assert.string o.text