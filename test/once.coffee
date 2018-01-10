EventEmitter = require 'events'
assert = require 'assert'
uuid = require 'uuid'
_ = require 'lodash'

once = require '../once'

emitter = null
q = null

pusher = (what, ret) ->
  ->
    q.push _.extend event: what, arguments
    ret

check_installed = (what) ->
  q = []
  id = uuid.v4()
  emitter.emit what, id
  assert.equal q.length, 1, 'something happened'
  assert.equal q[0].event, what, 'what happened'
  assert.equal q[0][0], id, 'id'
  q = null

check_absent = (what) ->
  q = []
  id = uuid.v4()
  emitter.emit what, id
  assert.equal q.length, 0, 'nothing happened'
  q = null

describe 'Once upon a time', ->
  handlers =
    alma: pusher 'alma'
    barac: pusher 'barac'

  before (done) ->
    emitter = new EventEmitter
    done()

  it 'install / kill', (done) ->
    kill = once.install emitter, handlers
    check_installed 'alma'
    check_installed 'barac'
    kill()
    check_absent 'alma'
    check_absent 'barac'
    done()

  it 'install / remove', (done) ->
    once.install emitter, handlers
    check_installed 'alma'
    check_installed 'barac'
    once.remove emitter, handlers
    check_absent 'alma'
    check_absent 'barac'
    done()

  it 'any', (done) ->
    once.any emitter, handlers
    check_installed 'alma'
    check_absent 'alma'
    check_absent 'barac'
    done()

  it 'while', (done) ->
    once.while emitter,
      alma: pusher 'alma', true
      barac: pusher 'barac', false
    check_installed 'alma'
    check_installed 'alma'
    check_installed 'barac'
    check_absent 'alma'
    check_absent 'barac'
    done()

  it 'until', (done) ->
    once.until emitter,
      alma: pusher 'alma', true
      barac: pusher 'barac', false
    check_installed 'barac'
    check_installed 'barac'
    check_installed 'alma'
    check_absent 'alma'
    check_absent 'barac'
    done()

  describe 'promise', ->
    it 'direct / resolve', ->
      once.promise emitter, handlers, (resolve, reject, kill) ->
        assert _.isFunction(resolve), 'resolve is function'
        assert _.isFunction(reject), 'reject is function'
        assert _.isFunction(kill), 'kill is function'
        check_installed 'alma'
        check_installed 'barac'
        setTimeout resolve, 2
      .then ->
        check_absent 'alma'
        check_absent 'barac'

    it 'direct / reject', ->
      marker = {}
      once.promise emitter, handlers, (resolve, reject, kill) ->
        assert _.isFunction(resolve), 'resolve is function'
        assert _.isFunction(reject), 'reject is function'
        assert _.isFunction(kill), 'kill is function'
        check_installed 'alma'
        check_installed 'barac'
        setTimeout ->
            check_installed 'alma'
            check_installed 'barac'
            error = new Error 'marker'
            error.marker = marker
            reject error
          , 2
      .then -> assert false, 'rejected'
      .catch ((error) -> error?.marker == marker), ->
        check_absent 'alma'
        check_absent 'barac'

    it 'callback', ->
      marker = {}
      setTimeout ->
          check_installed 'alma'
          check_installed 'barac'
          emitter.emit 'resolve', marker
        , 2
      once.promise emitter, (resolve, reject) ->
        assert _.isFunction(resolve), 'resolve is function'
        assert _.isFunction(reject), 'reject is function'
        _.extend {}, handlers,
          resolve: resolve
          reject: reject
      .then (res) ->
        assert.strictEqual res, marker, 'value'
        check_absent 'alma'
        check_absent 'barac'

    it 'callback reject', ->
      handlers_ = -> handlers
      once.promise emitter, handlers_, ->
        new Promise (resolve, reject) ->
          check_installed 'alma'
          check_installed 'barac'
          reject new Error 'Alma'
      .then ->
        assert false, 'should reject'
      .catch (error) ->
        assert /Alma/.test(error), 'rejected'
        check_absent 'alma'
        check_absent 'barac'

  describe 'promiseSimple', ->
    setup = (marker, cb) ->
      handlers_ = _.extend {}, handlers,
        resolve: 'resolve'
        reject: 'reject'
        return: marker
        id: (x) -> x
      once.promiseSimple emitter, handlers_, (resolve, reject, kill) ->
        assert _.isFunction(resolve), 'resolve is function'
        assert _.isFunction(reject), 'reject is function'
        assert _.isFunction(kill), 'kill is function'
        check_installed 'alma'
        check_installed 'barac'
        cb? resolve, reject, kill

    it 'resolve', ->
      marker = {}
      setup null, (resolve, reject, kill) ->
        setTimeout ->
            check_installed 'alma'
            check_installed 'barac'
            emitter.emit 'resolve', marker
          , 2
      .then (res) ->
        assert.strictEqual res, marker, 'value'
        check_absent 'alma'
        check_absent 'barac'

    it 'reject', ->
      marker = {}
      setup null, (resolve, reject, kill) ->
        setTimeout ->
            check_installed 'alma'
            check_installed 'barac'
            error = new Error 'marker'
            error.marker = marker
            emitter.emit 'reject', error
          , 2
      .then -> assert false, 'rejected'
      .catch ((error) -> error?.marker == marker), ->
        check_absent 'alma'
        check_absent 'barac'

    it 'return', ->
      marker = {}
      setup marker, (resolve, reject, kill) ->
        setTimeout ->
            check_installed 'alma'
            check_installed 'barac'
            emitter.emit 'return'
          , 2
      .then (res) ->
        assert.strictEqual res, marker, 'value'
        check_absent 'alma'
        check_absent 'barac'

    it 'handler', ->
      marker = {}
      setup null, (resolve, reject, kill) ->
        setTimeout ->
            check_installed 'alma'
            check_installed 'barac'
            emitter.emit 'id'
          , 2
        setTimeout ->
            check_installed 'alma'
            check_installed 'barac'
            emitter.emit 'id', marker
          , 4
      .then (res) ->
        assert.strictEqual res, marker, 'value'
        check_absent 'alma'
        check_absent 'barac'

  describe 'finally', ->
    it 'promise / resolve', ->
      marker = {}
      setTimeout ->
          check_installed 'alma'
          check_installed 'barac'
          emitter.emit 'resolve', marker
        , 2
      p = once.promiseSimple emitter,
        resolve: 'resolve'
        reject: 'reject'
      once.finally emitter, handlers, p
          .then (res) ->
            assert.strictEqual res, marker, 'value'
            check_absent 'alma'
            check_absent 'barac'

    it 'promise / reject', ->
      marker = {}
      setTimeout ->
          check_installed 'alma'
          check_installed 'barac'
          error = new Error 'marker'
          error.marker = marker
          emitter.emit 'reject', error
        , 2
      p = once.promiseSimple emitter,
        resolve: 'resolve'
        reject: 'reject'
      once.finally emitter, handlers, p
          .then -> assert false, 'rejected'
          .catch ((error) -> error?.marker == marker), ->
            check_absent 'alma'
            check_absent 'barac'

    it 'cb / resolve', ->
      marker = {}
      setTimeout ->
          check_installed 'alma'
          check_installed 'barac'
          emitter.emit 'resolve', marker
        , 2
      p = once.promiseSimple emitter,
        resolve: 'resolve'
        reject: 'reject'
      once.finally emitter, handlers, -> p
          .then (res) ->
            assert.strictEqual res, marker, 'value'
            check_absent 'alma'
            check_absent 'barac'

    it 'cb / reject', ->
      marker = {}
      setTimeout ->
          check_installed 'alma'
          check_installed 'barac'
          error = new Error 'marker'
          error.marker = marker
          emitter.emit 'reject', error
        , 2
      p = once.promiseSimple emitter,
        resolve: 'resolve'
        reject: 'reject'
      once.finally emitter, handlers, -> p
          .then -> assert false, 'rejected'
          .catch ((error) -> error?.marker == marker), ->
            check_absent 'alma'
            check_absent 'barac'
