AlienWsBase = require './ws-base'

class AlienWsJson extends AlienWsBase
  sendJSON: (obj) ->
    try
      @send JSON.stringify obj
    catch error
      @_syncError error, 'json-output'

  _onWsMessage: (data, flags) ->
    ret = super
    try
      if flags?.binary
        @_onWsjBinaryMessage data, flags
      else
        msg = JSON.parse data
        @debug? 'WsJsonMessage', msg
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
        error.pkt = msg ? data
        'json'
    @_asyncError error, "#{type}-input"
    null

module.exports = AlienWsJson
