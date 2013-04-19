assert = require("better-assert")
_ = require("underscore")

module.exports = _(assert).extend
	"ok": (x) -> assert x
	# Underscore functions
	"equal": (x, y) -> assert _.isEqual(x, y)
	"empty": (x) -> assert _.isEmpty(x)
	"element": (x,y) -> assert _.isElement(x,y)
	"array": (x) -> assert _.isArray(x)
	"object": (x) -> assert _.isObject(x)
	"arguments": (x) -> assert _.isArguments(x)
	"function": (x) -> assert _.isFunction(x)
	"string": (x) -> assert _.isString(x)
	"number": (x) -> assert _.isNumber(x)
	"finite": (x) -> assert _.isFinite(x)
	"boolean": (x) -> assert _.isBoolean(x)
	"date": (x) -> assert _.isDate(x)
	"regexp": (x) -> assert _.isRegExp(x)
	"NaN": (x) -> assert _.isNaN(x)
	"null": (x) -> assert _.isNull(x)
	"undefined": (x) -> assert _.isUndefined(x)
	# End underscore functions
	"defined": (x) -> assert !_.isUndefined(x)