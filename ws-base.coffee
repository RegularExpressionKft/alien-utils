_ = require 'lodash'

AlienCommander = require './commander'

# TODO Proper semantics and plugin/patch/extension implementation plan
#      for high level events (open, close, fail, etc..)
# TODO Safer, simpler cleanup for tests
class AlienWsBase extends AlienCommander
  _READY_STATE:
    CONNECTING: 0
    OPEN: 1
    CLOSING: 2
    CLOSED: 3

  # ==== Public API ====

  @fromAlienServer: (master, ws, params) ->
    req = ws.upgradeReq
    self = req.alienLogger.decorate(
      new @ null,
        params: params
        master: master
        app: master.app
        id: req.alienUuid
        req: req
    )._addWebSocket ws
    req.emit 'alien-upgrade', self
    self

  constructor: (ws, reset) ->
    if @constructor._plugins?
      fn @ for n, fn of @constructor._plugins

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
    if @ws?
      if !@closing
        @emit 'closing', code, data
        @_setStatus 'closing'
      @_wsClose code, data
    @

  close: (code, data) ->
    if (error = @_checkClose code, data)?
      @_syncError "close: #{error}", 'close'
    else
      @_close code, data

  # Gets rid of @ for good no matter what, no checks, no exceptions
  # No guarantees on calling hooks or anything else
  terminate: (code, data) ->
    @_close code, data
    @

  fail: (error = 'Unknown error') ->
    @emit 'fail', error
    if @error?
      if error.ws_pkt?
        @error "ws error #{error}", error.ws_pkt
      else
        @error "ws error #{error}", error
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
    if @ws.readyState == @_READY_STATE.OPEN
      @wsPendingOps.read = true
      @emit 'open' unless 'open' is @_setStatus 'open'
    @debug? 'AlienWs open', @id
    @emit 'wsOpen', arguments...
    null

  _onWsClosed: ->
    delete @wsPendingOps.close
    @debug? 'AlienWs closed'
    @emit 'wsClosed', arguments...
    @emit 'closed' unless 'closed' is @_setStatus 'closed'
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
    if @ws?
      msg = if error instanceof Error then error.ws_msg else error
      code = error.ws_code ? if @ws.browser then 4000 else 1002
      @_close code, msg ? 'Unknown error'
    null

  _onWsInternalError: (error, event, args) ->
    error?.ws_pkt = args[0] if event is 'message'
    @error? 'ws internal error', error
    @_abort error

  # ==== Add / remove ws ====

  _resetDefaults:
    wsPendingOps: {}
    terminating: false
    status: 'init'
    ws: null

  _statuses: [ 'init', 'connecting', 'open', 'closing', 'closed' ]

  _setStatus: (status = 'invalid') ->
    unless status in @_statuses
      @_syncError "Trying to set invalid status: #{status}", 'setStatus'

    was = @status ? 'init'
    for st in @_statuses
      @[st] = st is status
    @status = status
    was

  _reset: (state) ->
    _.extend @, @_resetDefaults, state
    @_setStatus @status
    @

  _wrapBrowserWs: (ws) ->
    _.defaults ws,
      browser: true
      on: (event, cb) ->
        switch event
          when 'message'
            # TODO binary, masked
            @addEventListener event, (e) ->
              cb.call @, e.data, {}
          when 'close'
            @addEventListener event, (e) ->
              cb.call @, e.code, e.reason
          # TODO when 'error' ???
          else
            @addEventListener arguments...
      once: (event, cb) ->
        self = @
        listener = ->
          self.removeEventListener event, listener
          cb.apply @, arguments
        @on arguments...

  _addWebSocket: (ws, reset) ->
    @_retireWebSocket @ws if @ws?
    @_reset reset

    ws = @_wrapBrowserWs ws if WebSocket? and ws instanceof WebSocket

    @_wsInstallHandlers @ws = ws
    switch @ws.readyState
      when @_READY_STATE.CONNECTING
        @_setStatus 'connecting'
      when @_READY_STATE.OPEN
        @_onWsOpen()
      when @_READY_STATE.CLOSING
        @_setStatus 'closing'
      when @_READY_STATE.CLOSED
        @_setStatus 'closed'

    @

  _retireWebSocket: (ws) ->
    try
      ws.close()
    catch error
      # nop
    @

  # ==== High level api helpers, plugins, patch points ====
  # Checkers return error

  _checkWs: ->
    if @ws? then null else 'no websocket'

  checkWsOpen: ->
    if @open then null else "websocket is #{@status ? 'init'}"

  # _checkClose: (code, data) ->
  _checkClose: ->
    @_checkWs()

  _checkSend: (data, flags) ->
    @_checkWs() ? @checkWsOpen()

  # ==== Low level api

  _wsClose: ->
    @_onWsClosing arguments...
    @wsPendingOps.close = true

    # Sometimes there is no close event.
    fired = false
    @ws.once 'close', -> fired = true
    @ws.close arguments...
    # @ws.close may emit closed event clearing @ws
    if @ws?.readyState == @_READY_STATE.CLOSED
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
