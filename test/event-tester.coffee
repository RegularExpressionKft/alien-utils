EventEmitter = require 'events'
assert = require 'assert'

EventTester = require '../event-tester'

describe 'EventTester', ->
  describe 'Simple', ->
    emitter = new EventEmitter
    tester = null

    fired = false
    handler = -> fired = true

    it 'creates', (done) ->
      tester = new EventTester emitter
      assert (tester instanceof EventTester), 'ISA EventTester'
      assert.strictEqual tester.emitter, emitter, 'tester.emitter'
      done()

    it 'installs', (done) ->
      fired = false
      tester.install 'apokalipszis', handler
      tester.install 'vitriol', handler
      assert !fired, 'not yet fired'

      emitter.emit 'apokalipszis'
      setImmediate ->
        assert fired, 'fired'
        done()

    it 'removes', (done) ->
      fired = false
      tester.remove 'apokalipszis', handler
      assert !fired, 'not yet fired'

      emitter.emit 'apokalipszis'
      setImmediate ->
        assert !fired, 'not fired'

        emitter.emit 'vitriol'
        setImmediate ->
          assert fired, 'fired'
          done()

    it 'done', (done) ->
      fired = false
      tester.done()

      emitter.emit 'vitriol'
      setImmediate ->
        assert !fired, 'not fired'
        done()
