_ = require 'lodash'

class EventTester
  constructor: (@emitter) -> return @reset()

  reset: ->
    @objects = []
    @listeners = []
    @

  install: (emitter, event, cb) ->
    # .on event, cb
    if _.isString emitter
      cb = event
      event = emitter
      emitter = @emitter

    emitter_idx = @objects.findIndex (x) -> x == emitter
    emitter_idx = -1 + @objects.push emitter if emitter_idx < 0

    events = @listeners[emitter_idx] ?= {}
    listeners = events[event] ?= []
    listeners.push cb

    emitter.on event, cb
    @

  remove: (emitter, event, cb) ->
    # .remove event, cb
    if _.isString emitter
      cb = event
      event = emitter
      emitter = @emitter

    emitter_idx = @objects.findIndex (x) -> x == emitter
    if emitter_idx < 0
      throw new Error 'Trying to remove listeners for unregistered emitter'

    if event?
      unless (events = @listeners[emitter_idx])?
        throw new Error 'Something is not right'
      unless (listeners = events[event])?
        throw new Error 'Trying to remove listeners for unregistered event'

      if cb?
        cb_idx = listeners.findIndex (x) -> x == cb
        if cb_idx < 0
          throw new Error 'Trying to remove unregistered listener'
        listeners.splice cb_idx, 1
        delete events[event] unless listeners.length > 0
        emitter.removeListener event, cb
      else
        emitter.removeListener event, l for l in listeners
        delete events[event]
    else
      throw new Error 'Wot m8?' if cb?

      for e, listeners of @listeners[emitter_idx]
        emitter.removeListener e, l for l in listeners
      @listeners[emitter_idx] = {}

    @

  done: ->
    for emitter_idx, emitter of @objects
      for e, listeners of @listeners[emitter_idx]
        emitter.removeListener e, l for l in listeners
    @reset()

module.exports = EventTester
