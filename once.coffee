Promise = require 'bluebird'
_ = require 'lodash'

remove = (emitter, handlers) ->
  emitter.removeListener event, handler for event, handler of handlers
  emitter

install = (emitter, handlers) ->
  emitter.on event, handler for event, handler of handlers
  -> remove emitter, handlers

module.exports =
  remove: remove
  install: install

  any: (emitter, handlers) ->
    handlers_ = _.mapValues handlers, (handler, event) ->
      ->
        remove emitter, handlers_
        handler.apply @, arguments
    install emitter, handlers_
  while: (emitter, handlers) ->
    handlers_ = _.mapValues handlers, (handler, event) ->
      -> remove emitter, handlers_ unless handler.apply @, arguments
    install emitter, handlers_
  until: (emitter, handlers) ->
    handlers_ = _.mapValues handlers, (handler, event) ->
      -> remove emitter, handlers_ if handler.apply @, arguments
    install emitter, handlers_

  promise: (emitter, handlers_cb, cb) ->
    kill = null
    new Promise (resolve, reject) ->
      kill = if _.isFunction handlers_cb
          install emitter, handlers_cb resolve, reject
        else
          install emitter, handlers_cb
      cb? resolve, reject, kill
    .finally -> kill?()

  promiseSimple: (emitter, handlers, cb) ->
    kill = null
    new Promise (resolve, reject) ->
      kill = install emitter, _.mapValues handlers, (handler, event) ->
        if handler is 'resolve'
          resolve
        else if handler is 'reject'
          reject
        else if _.isFunction handler
          ->
            try
              ret = handler.apply @, arguments
              resolve ret if ret?
            catch error
              reject error
        else
          -> resolve handler
      cb? resolve, reject, kill
    .finally -> kill?()

  finally: (emitter, handlers, cb) ->
    kill = install emitter, handlers
    if _.isFunction cb.finally
      cb.finally kill
    else
      cb_ = Promise.method cb
      cb_(kill).finally kill
