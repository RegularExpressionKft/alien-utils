Commander = require '../commander'
assert = require 'assert'

class TesterBase extends Commander
  cmds: @commands
    inherit: 'inheritMethod'
    method: 'cmdMethod'
    fun: -> 'sparrow'
  cmd: (cmd, args...) -> @cmds.apply cmd, @, args
  inheritMethod: -> 'among'
  cmdMethod: -> 'key'
  

class TesterDerived extends TesterBase
  cmds: @::cmds.derive
    method: 'anotherMethod'
    hasOwnProperty: -> 'hopeless'
  anotherMethod: -> 'heaving'
  inheritMethod: -> 'moaning'

describe 'Commander', ->
  describe 'Base', ->
    obj = new TesterBase

    it 'inherit', (done) ->
      ret = obj.cmd 'inherit'
      assert.equal ret, 'among', 'base.inherit'
      done()

    it 'method', (done) ->
      ret = obj.cmd 'method'
      assert.equal ret, 'key', 'base.method'
      done()

    it 'fun', (done) ->
      ret = obj.cmd 'fun'
      assert.equal ret, 'sparrow', 'base.fun'
      done()

    it 'hasOwnProperty', (done) ->
      try
        obj.cmd 'hasOwnProperty', 'cmds'
        assert false, 'base.hasOwnProperty'
      catch error
        assert "#{error}".match(/Unknown command: hasOwnProperty/),
          'base.hasOwnProperty error'
        done()

  describe 'Derived', ->
    obj = new TesterDerived

    it 'inherit', (done) ->
      ret = obj.cmd 'inherit'
      assert.equal ret, 'moaning', 'derived.inherit'
      done()

    it 'method', (done) ->
      ret = obj.cmd 'method'
      assert.equal ret, 'heaving', 'derived.method'
      done()

    it 'fun', (done) ->
      ret = obj.cmd 'fun'
      assert.equal ret, 'sparrow', 'derived.fun'
      done()

    it 'hasOwnProperty', (done) ->
      ret = obj.cmd 'hasOwnProperty', 'cmds'
      assert.equal ret, 'hopeless', 'derived.hasOwnProperty'
      done()
