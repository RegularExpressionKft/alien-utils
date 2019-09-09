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

  isBinaryMessage: (data) -> Buffer.isBuffer data

  _onWsMessage: (data) ->
    ret = super
    try
      if @isBinaryMessage data
        @_onWsjBinaryMessage data
      else
        msg = JSON.parse data
        @_onWsjJsonMessage msg, data
    catch error
      @_onWsjBadMessage error, msg, data
    ret

  # _onWsjBinaryMessage: (data) -> null
  # _onWsjJsonMessage: (msg, data) -> null

  _onWsjBadMessage: (error, msg, data) ->
    error = new Error error unless error instanceof Error
    type =
      if @isBinaryMessage data
        'binary'
      else
        error.ws_pkt = msg ? data
        'json'
    @_asyncError error, "#{type}-input"
    null

module.exports = AlienWsJson
