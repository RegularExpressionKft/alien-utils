Promise = require 'bluebird'
_ = require 'lodash'

remove = (emitter, handlers) ->
  emitter.removeListener event, handler for event, handler of handlers
  emitter

install = (emitter, handlers) ->
  emitter.on event, handler for event, handler of handlers
  _.once -> remove emitter, handlers

promise = (emitter, handlers_cb, cb) ->
  kill = null

  p_cb_resolve = p_cb_reject = null
  p_cb = new Promise (resolve, reject) ->
    p_cb_resolve = resolve
    p_cb_reject = reject
    null

  p_once = new Promise (resolve, reject) ->
    kill = if _.isFunction handlers_cb
        install emitter, handlers_cb resolve, reject
      else
        install emitter, handlers_cb

    p =
      if _.isFunction cb
        Promise.method(cb) resolve, reject, kill
      else
        Promise.resolve cb
    p.then p_cb_resolve, p_cb_reject

  Promise.join p_cb, p_once, (a, b) -> b
         .finally -> kill?()

module.exports =
  remove: remove
  install: install
  promise: promise

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


  promiseSimple: (emitter, handlers, cb) ->
    mapper = (resolve, reject) ->
      _.mapValues handlers, (handler, event) ->
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
    promise emitter, mapper, cb

  finally: (emitter, handlers, cb) ->
    kill = install emitter, handlers
    if _.isFunction cb.finally
      cb.finally kill
    else
      cb_ = Promise.method cb
      cb_(kill).finally kill
