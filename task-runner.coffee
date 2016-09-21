EventEmitter = require 'events'
Promise = require 'bluebird'
_ = require 'lodash'

# Promise.(join|all) and async.parallel both give up on first error.
# TaskRunner only signals finished when all tasks have finished.

class TaskRunner extends EventEmitter
  constructor: (handler) ->
    @pending = {}
    @results = {}
    @on 'finished', handler if handler?
    return @

  start: (tasks) ->
    throw new Error "Already finished" if @finished

    for k of tasks when @pending[k]?
      throw new Error "Can't run multiple instances of: #{k}"

    _.forEach tasks, (task, task_name) =>
      callback = (args...) =>
        process.nextTick =>
          if @pending[task_name]
            [error, results...] = args
            delete @pending[task_name]

            if error
              @errors ?= {}
              @errors[task_name] = error
              @emit 'task_failed', task_name, error
            else
              if @errors?[task_name]?
                delete @errors[task_name]
                delete @errors if _.isEmpty @errors
              @results[task_name] = results
              @emit 'task_succesful', task_name, results...
            @emit 'task_finished', task_name, args...

            @emit 'finished', @errors, @results if _.isEmpty @pending
          else
            @emit 'error', new Error "Callback re-invoked: #{task_name}"
          null
        null

      try
        @pending[task_name] = true
        p = task callback
      catch error
        callback error

      try
        if p? and _.isFunction p.then
          p.then (results...) -> callback null, results...
           .catch (error) -> callback error
      catch error
        # p was not a proper promise, task shall call callback
    @

  @start: (tasks, handler) -> (new @ handler).start tasks

  @promise: (tasks) ->
    new Promise (resolve, reject) =>
      try
        (new @).once 'finished', (errors, results) ->
                 if errors?
                   errors[':results'] = results unless _.isEmpty results
                   reject errors
                 else
                   resolve results
               .start tasks
      catch error
        reject error

module.exports = TaskRunner
