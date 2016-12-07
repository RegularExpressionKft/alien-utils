_ = require 'lodash'
WebSocket = require 'ws'

AlienCommander = require './commander'

# TODO Proper semantics and plugin/patch/extension implementation plan
#      for high level events (open, close, fail, etc..)
# TODO Safer, simpler cleanup for tests
class AlienWsBase extends AlienCommander
  # ==== Public API ====

  @fromAlienServer: (master, ws, params, next) ->
    req = ws.upgradeReq
    req.alienLogger.decorate(
      new @ null,
        params: params
        master: master
        app: master.app
        id: req.alienUuid
    )._addWebSocket ws

  constructor: (ws, reset) ->
    @_reset reset
    @_addWebSocket ws if ws?
    return @

  send: (data, flags, cb) ->
    if !cb? and _.isFunction flags
      cb = flags
      flags = null
    if (error = @_checkSend data, flags)?
      @_syncError "send: #{error}", 'send'
    else
      @_wsSend data, flags, cb

  sendBinary: (data, flags, cb) ->
    if !cb? and _.isFunction flags
      cb = flags
      flags = null
    @send data, _.extend(binary: true, flags), cb

  _close: (code, data) ->
    if !@closing
      @emit 'closing', code, data
      @closing = true
    @_wsClose code, data

  close: (code, data) ->
    if (error = @_checkClose code, data)?
      @_syncError "close: #{error}", 'close'
    else
      @_close code, data

  # Gets rid of @ for good no matter what, no checks, no exceptions
  # No guarantees on calling hooks or anything else
  terminate: (code, data) ->
    @terminating = true
    if (error = @_checkClose code, data)?
      @_wsClose code, data if @ws?
    else
      @_close code, data
    @

  fail: (error = 'Unknown error') ->
    @emit 'fail', error
    if @error?
      if error.ws_pkt?
        @error error, error.ws_pkt
      else
        @error error
    @_abort error if @ws?
    @

  # ==== Event handlers ====

  _wsEventHandlers: @commands
      open: '_onWsOpen'
      close: '_onWsClosed'
      message: '_onWsMessage'
      error: '_onWsError'
    ,
      what: 'event'

  _onWsOpen: ->
    if @ws.readyState == WebSocket.OPEN
      @wsPendingOps.read = true
      @open = true
    @debug? 'AlienWs open'
    @emit 'wsOpen', arguments...
    null

  _onWsClosed: ->
    delete @wsPendingOps.close
    @open = false
    @debug? 'AlienWs closed'
    @emit 'wsClosed', arguments...
    @emit 'closed' if @closing
    @_reset()
    null

  _onWsMessage: ->
    @emit 'wsMessage', arguments...
    null

  _onWsError: (error) ->
    @debug? 'AlienWs error', error
    @emit 'wsError', arguments...
    ops = _.keys @wsPendingOps
    @_asyncError error, if ops.length > 0 then ops.join() else 'no-op'
    null

  _wsInstallHandlers: (ws) ->
    @_wsEventHandlers.keys().forEach (event) =>
      ws.on event, =>
        try
          if @ws == ws
            @_wsEventHandlers.apply event, @, arguments
          else
            @debug? "stale WS event: #{event}"
        catch error
          @_onWsInternalError error, event, arguments
        null
    @

  # ---- internal

  _onWsClosing: ->
    @emit 'wsClosing', arguments...
    null

  _onWsSent: (data, flags) ->
    # @emit 'wsSent', data, flags
    null

  # ==== Error handling ====

  # high level api sync error
  _syncError: (error, op) ->
    error = new Error error unless error instanceof Error
    throw error

  # high level api async error
  _asyncError: (error, op) ->
    @emit 'error', error, op if @listenerCount('error') > 0
    @fail error
    null

  # fail business end
  _abort: (error) ->
    msg = if error instanceof Error then error.ws_msg else error
    @_wsClose error.ws_code ? 1002, msg ? 'Unknown error'

  _onWsInternalError: (error, event, args) ->
    error?.ws_pkt = args[0] if event is 'message'
    @abort error

  # ==== Add / remove ws ====

  _resetDefaults:
    wsPendingOps: {}
    wsClosing: false
    closing: false # ?
    open: false
    ws: null

  _reset: (state) ->
    _.extend @, @_resetDefaults, state

  _addWebSocket: (ws, reset) ->
    @_retireWebSocket @ws if @ws?
    @_reset reset
    @_wsInstallHandlers @ws = ws
    @_onWsOpen() if @ws.readyState == WebSocket.OPEN
    @

  _retireWebSocket: (ws) ->
    ws.close()
    @

  # ==== High level api helpers, plugins, patch points ====
  # Checkers return error

  _checkWs: ->
    if @ws? then null else 'no websocket'

  checkWsClosing: ->
    if @wsClosing then 'websocket is closed' else null

  # _checkClose: (code, data) ->
  _checkClose: ->
    @_checkWs()

  _checkSend: (data, flags) ->
    @_checkWs() ? @checkWsClosing()

  # ==== Low level api

  _wsClose: ->
    @_onWsClosing arguments...
    @wsPendingOps.close = true
    @wsClosing = true

    # Sometimes there is no close event.
    fired = false
    @ws.once 'close', -> fired = true
    @ws.close arguments...
    if @ws.readyState == WebSocket.CLOSED
      @_onWsClosed() unless fired
      delete @wsPendingOps.close
    @

  _wsSend: (data, flags, cb) ->
    if !cb? and _.isFunction flags
      cb = flags
      flags = null
    @ws.send data, flags, (error) =>
      cb? arguments...
      if error?
        @_onWsError error, 'send'
      else
        @_onWsSent data, flags
      null
    @

module.exports = AlienWsBase
