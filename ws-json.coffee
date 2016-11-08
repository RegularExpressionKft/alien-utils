_ = require 'lodash'

AlienWsBase = require './ws-base'

class AlienWsJson extends AlienWsBase
  sendJSON: (obj, flags, cb) ->
    if !cb? and _.isFunction flags
      cb = flags
      flags = null
    try
      @send JSON.stringify(obj), flags, cb
    catch error
      cb? error
      @_syncError error, 'json-output'

  _onWsMessage: (data, flags) ->
    ret = super
    try
      if flags?.binary
        @_onWsjBinaryMessage data, flags
      else
        msg = JSON.parse data
        @_onWsjJsonMessage msg, data, flags
    catch error
      @_onWsjBadMessage error, msg, data, flags
    ret

  # _onWsjBinaryMessage: (data, flags) -> null
  # _onWsjJsonMessage: (msg, data, flags) -> null

  _onWsjBadMessage: (error, msg, data, flags) ->
    error = new Error error unless error instanceof Error
    type = if flags?.binary
        'binary'
      else
        error.ws_pkt = msg ? data
        'json'
    @_asyncError error, "#{type}-input"
    null

module.exports = AlienWsJson
