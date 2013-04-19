assert = require("pretty-assert")
_ = require("underscore")
sinon = require("sinon")

#TODO: figure out a way to move async setup to the fixture and out of the test

dbCallStub = () ->
	stub = {}
	stub.success = (successCb) ->
		assert ! _(stub).has "successCb"
		stub.successCb = successCb
		return stub
	stub.failure = (failureCb) ->
		assert ! _(stub).has "failureCb"
		stub.failureCb = failureCb
		return stub
	stub.verifySetup = () ->
		assert _(stub).has "failureCb"
		assert _(stub).has "successCb"
	stub.succeed = (result) ->
		stub.verifySetup()
		stub.successCb(result)
	stub.fail = (result, errValue) ->
		stub.verifySetup()
		stub.failureCb(result, errValue)
	stub
	
describe 'Common', ->
	describe 'timesOfDay()', ->
		it 'should be 25 options', ->
			require("../common").sync (common) ->
				assert.equal(25, common.timesOfDay.length)
		it 'should contain only valid values', ->
			require("../common").sync (common) ->
				for o in common.timesOfDay
					assert.finite o.value
					assert.string o.text
	describe 'ectConfig.timezones', ->
		it 'should contain only valid values', ->
			require("../common").sync (common) ->
				for o in common.ectConfig.timezones
					assert.defined o.id
	describe 'dbCallStub', ->
		it 'should call a success function with exactly one argument on success', ->
			dbcs = dbCallStub()
			
			successStub = sinon.spy()
			failureStub = sinon.spy()
			dbcs.success(successStub).failure(failureStub)
			dbcs.verifySetup()
			magicValue = 100
			dbcs.succeed(magicValue)

			assert successStub.calledOnce
			assert !failureStub.called
			assert successStub.alwaysCalledWithExactly(magicValue)			
		it 'should call a failure function with exactly two arguments on failure, the first null', ->		
			dbcs = dbCallStub()
			
			successStub = sinon.spy()
			failureStub = sinon.spy()
			dbcs.success(successStub).failure(failureStub)
			dbcs.verifySetup()
			magicValue = 101
			dbcs.fail(undefined, magicValue)

			assert ! successStub.called
			assert failureStub.calledOnce
			assert failureStub.alwaysCalledWithExactly(undefined, magicValue)
	describe 'successFail', ->
		successFail = require("../common").successFail
		it 'should call a function with exactly one argument on success', ->
			debugger;
			dbcs = dbCallStub()
			cb = sinon.spy()
			successFail dbcs, cb
			dbcs.verifySetup()
			magicValue = 102
			dbcs.succeed(magicValue)

			assert cb.calledOnce
			assert cb.alwaysCalledWithExactly(magicValue)
		it 'should call a function with exactly two arguments on failure, the first null', ->
			dbcs = dbCallStub()			
			cb = sinon.spy()
			successFail dbcs, cb
			dbcs.verifySetup()
			magicValue = 103
			dbcs.fail("SHOULD NOT BE SEEN", magicValue)

			console.log(cb.callCount)
			assert cb.calledOnce
			assert cb.alwaysCalledWithExactly(undefined, magicValue)
