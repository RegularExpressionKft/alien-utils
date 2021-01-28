heartbeat = (ws, timeout_ms, period_ms) ->
  wsp = ws:: ? ws

  if !wsp.heartbeat
    # config
    wsp.heartbeat_timeout_ms = timeout_ms if timeout_ms?
    wsp.heartbeat_period_ms = period_ms if period_ms?

    # receive
    ws.addMessageTypes
      heartbeat: (msg) ->
        @heartbeatReceived msg
        null

    wsp.heartbeatReceived ?= (msg) ->
      @last_heartbeat = Date.now()

      if @_heartbeat_recv_timer?
        clearTimeout @_heartbeat_recv_timer
        @_heartbeat_recv_timer = null

      if @heartbeat_timeout_ms?
        if @heartbeat_timeout_ms < 0
          @heartbeat_timeout_ms = -@heartbeat_timeout_ms

        @_startHeartbeatTimer @heartbeat_timeout_ms if @heartbeat_timeout_ms > 0

      if @heartbeat_period_ms? and @heartbeat_period_ms < 0
        @heartbeat_period_ms = -@heartbeat_period_ms
        @setupHeartbeat()

      @emit 'heartbeat', msg

      null

    wsp._startHeartbeatTimer ?= (t) ->
      timer = setTimeout =>
          @_heartbeat_recv_timer = null if @_heartbeat_recv_timer == timer
          @_onHeartbeatTimeout() if @open
          null
        , t
      timer.unref()
      @_heartbeat_recv_timer = timer

    wsp._onHeartbeatTimeout ?= ->
      @info? 'heartbeat timeout'
      @emit 'heartbeat_timeout'
      if @reconnect then @connect() else @close()

    # send
    wsp.sendHeartbeat ?= ->
      @sendJSON type: 'heartbeat'

    wsp.setupHeartbeat ?= ->
      if @_heartbeat_send_timer?
        clearTimeout @_heartbeat_send_timer
        @_heartbeat_send_timer = null

      if @heartbeat_period_ms? and @heartbeat_period_ms > 0
        t = @heartbeat_period_ms * (0.5 + 0.5 * Math.random())
        @_heartbeat_send_timer = setTimeout =>
            if @open
              @sendHeartbeat()
              @setupHeartbeat()
            null
          , t
        @_heartbeat_send_timer.unref()

      if !@_heartbeat_recv_timer? and
         @heartbeat_timeout_ms? and
         @heartbeat_timeout_ms > 0
        t = @heartbeat_timeout_ms
        if @last_heartbeat?
          t -= Date.now() - @last_heartbeat
          t = 10 if t < 10

        @_startHeartbeatTimer t

      null

    wsp.cleanupHeartbeat ?= ->
      if @_heartbeat_recv_timer?
        clearTimeout @_heartbeat_recv_timer
        @_heartbeat_recv_timer = null
      if @_heartbeat_send_timer?
        clearTimeout @_heartbeat_send_timer
        @_heartbeat_send_timer = null
      @last_heartbeat = null
      null

    wsp.heartbeat = true

  if ws.send?
    ws.on 'wsOpen', ->
      @cleanupHeartbeat()
      @setupHeartbeat()
    ws.on 'wsClosed', -> @cleanupHeartbeat()
    ws.setupHeartbeat() if ws.open
  else
    ws._plugins ?= {}
    ws._plugins.heartbeat = (new_ws) ->
      new_ws.setupHeartbeat()
      null

  ws

module.exports = heartbeat
