assert = require("pretty-assert")
_ = require("underscore")
sinon = require("sinon")
successFail = require("../database/model").successFail

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
	stub.fail = (errValue) ->
		stub.verifySetup()
		stub.failureCb(errValue)
	stub

magicValue = 0
makeMagicValue = () ->
	magicValue += 1
	return magicValue

describe 'model', ->
	describe '(dbCallStub)', ->
		it 'should call a success function with exactly one argument on success', ->
			dbcs = dbCallStub()
			
			successStub = sinon.spy()
			failureStub = sinon.spy()
			dbcs.success(successStub).failure(failureStub)
			dbcs.verifySetup()
			magicValue = makeMagicValue()
			dbcs.succeed(magicValue)

			assert successStub.calledOnce
			assert !failureStub.called
			assert successStub.alwaysCalledWithExactly(magicValue)			
		it 'should call a failure function with exactly one argument on failure', ->
			dbcs = dbCallStub()
			
			successStub = sinon.spy()
			failureStub = sinon.spy()
			dbcs.success(successStub).failure(failureStub)
			dbcs.verifySetup()
			magicValue = makeMagicValue()
			dbcs.fail(magicValue)

			assert ! successStub.called
			assert failureStub.calledOnce
			assert failureStub.alwaysCalledWithExactly(magicValue)
	describe '.successFail', ->
		it 'should call a function with exactly one argument on success', ->
			dbcs = dbCallStub()
			cb = sinon.spy()
			successFail dbcs, cb
			dbcs.verifySetup()
			magicValue = makeMagicValue()
			dbcs.succeed(magicValue)

			assert cb.calledOnce
			assert cb.alwaysCalledWithExactly(magicValue)
		it 'should call a function with exactly two arguments on failure, the first undefined', ->
			dbcs = dbCallStub()			
			cb = sinon.spy()
			successFail dbcs, cb
			dbcs.verifySetup()
			magicValue = makeMagicValue()
			dbcs.fail(magicValue)

			assert cb.calledOnce
			assert cb.alwaysCalledWithExactly(undefined, magicValue)
