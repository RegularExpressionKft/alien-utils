assert = require 'assert'
_ = require 'lodash'

TaskRunner = require '../task-runner'

later = (ms, finished, key, cb_args...) ->
  (cb) ->
    setTimeout ->
        finished[key] = true
        cb cb_args...
      , ms
    null

describe 'TaskRunner', ->
  it 'great success', (done) ->
    finished = {}
    TaskRunner.start
        odin: later 50, finished, 'odin', null, 'one'
        dva: later 100, finished, 'dva', null, 'two'
      , (errors, results) ->
        assert finished.odin, 'odin finished'
        assert finished.dva, 'dva finished'

        assert !errors?, 'no errors'

        assert _.isObject(results), 'results is object'
        assert.deepEqual results.odin, [ 'one' ], 'results.odin'
        assert.deepEqual results.dva, [ 'two' ], 'results.dva'
        assert _.isEmpty(_.omit results, [ 'odin', 'dva' ]), 'results.else'

        done()

  it 'fast error', (done) ->
    finished = {}
    TaskRunner.start
        fastError: later 10, finished, 'fastError', 'quick'
        slow: later 100, finished, 'slow'
      , (errors, results) ->
        assert finished.fastError, 'fastError finished'
        assert finished.slow, 'slow finished'

        assert _.isObject(errors), 'errors is object'
        assert.equal errors.fastError, 'quick', 'errors.fastError'
        assert _.isEmpty(_.omit errors, 'fastError'), 'errors.else'

        assert _.isObject(results), 'results is object'
        assert.deepEqual results.slow, [], 'results.slow'
        assert _.isEmpty(_.omit results, 'slow'), 'results.else'

        done()

  it 'promise > cb', (done) ->
    finished = {}
    TaskRunner.start
        resolve: ->
          new Promise (resolve, reject) ->
            setTimeout ->
                finished.resolve = true
                resolve 'vixen'
              , 100
        reject: ->
          new Promise (resolve, reject) ->
            setTimeout ->
                finished.reject = true
                reject 'barbershop'
              , 10
      , (errors, results) ->
          assert finished.resolve, 'resolve finished'
          assert finished.reject, 'reject finished'
          assert.deepEqual errors, (reject: 'barbershop'), 'errors'
          assert.deepEqual results, (resolve: [ 'vixen' ]), 'results'
          done()

  it 'cb > promise', ->
    finished = {}
    TaskRunner.promise
                spencer: later 20, finished, 'spencer', null, 'bud'
                hill: later 10, finished, 'hill', null, 'terence'
              .then (results) ->
                assert finished.spencer, 'resolve spencer'
                assert finished.hill, 'reject hill'
                assert.deepEqual results,
                    spencer: [ 'bud' ]
                    hill: [ 'terence' ]
                  , 'results'

  it 'promise error', ->
    finished = {}
    TaskRunner.promise
                steinberg: later 20, finished, 'steinberg', null, 'hill'
                mason: later 10, finished, 'mason', new Error 'is no longer'
              .then -> assert false, 'rejected'
              .catch (errors) ->
                assert finished.steinberg, 'resolve steinberg'
                assert finished.mason, 'reject mason'
                assert _.isObject(errors), 'errors is object'
                assert (errors.mason instanceof Error), 'errors.mason'
                assert.deepEqual errors[':results'],
                    steinberg: [ 'hill' ]
                  , 'results'
