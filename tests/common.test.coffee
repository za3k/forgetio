common = require("../common")
assert = require("../pretty-assert")

describe 'Common', ->
	describe 'timesOfDay()', ->
		it 'should be 25 options', ->
			assert.equal(25, common.timesOfDay.length)
		it 'should contain only valid values', ->
			for o in common.timesOfDay
				assert.finite o.value
				assert.string o.text
	describe 'ectConfig.timezones', ->
		it 'should contain only valid values', ->
			for o in common.ectConfig.timezones
				assert.defined o.id
