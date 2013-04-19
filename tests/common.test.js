// Generated by CoffeeScript 1.6.2
var assert, common;

common = require("../common");

assert = require("../pretty-assert");

describe('Common', function() {
  describe('timesOfDay()', function() {
    it('should be 25 options', function() {
      return assert.equal(25, common.timesOfDay.length);
    });
    return it('should contain only valid values', function() {
      var o, _i, _len, _ref, _results;

      _ref = common.timesOfDay;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        o = _ref[_i];
        assert.finite(o.value);
        _results.push(assert.string(o.text));
      }
      return _results;
    });
  });
  return describe('ectConfig.timezones', function() {
    return it('should contain only valid values', function() {
      var o, _i, _len, _ref, _results;

      _ref = common.ectConfig.timezones;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        o = _ref[_i];
        _results.push(assert.defined(o.id));
      }
      return _results;
    });
  });
});