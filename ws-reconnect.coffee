Promise = require 'bluebird'
WebSocket = require 'ws'
_ = require 'lodash'

alienReconnectWs = (alien_ws, connect_url, connect_protocols) ->
  _.defaultsDeep alien_ws,
    # TODO config
    reconnectWaitMin: 1000
    reconnectWaitMax: 60000
    reconnectWaitMul: 2

    _resetDefaults:
      _wsrcConnecting: false

    reconnect: true

    connect: (url, protocols) ->
      if (error = @_wsrcCheckConnect url, protocols)?
        @_syncError error, 'connect'
      else
        @_wsrcResetTimer()
        @emit 'connecting', url, protocols
        @_wsrcConnect url, protocols

    _wsrcResetTimer: ->
      clearTimeout @_wsrcTimer if @_wsrcTimer?
      @_wsrcWaitAcc = null
      @_wsrcTimer = null
      @

    _wsrcWait: ->
      if @_wsrcWaitAcc?
        @_wsrcWaitAcc = @_wsrcWaitAcc * @reconnectWaitMul
        @_wsrcWaitAcc = @reconnectWaitMin if @_wsrcWaitAcc < @reconnectWaitMin
        @_wsrcWaitAcc = @reconnectWaitMax if @_wsrcWaitAcc > @reconnectWaitMax
      else
        @_wsrcWaitAcc = 0
      if @_wsrcWaitAcc > 0
        @_wsrcWaitAcc / 2 + Math.floor @_wsrcWaitAcc * Math.random()
      else
        0

    _wsrcCheckConnect: (url, protocols) ->
      if url? or @url?
        null
      else
        'connect: no url'

    _wsrcConnect: (url_, protocols_) ->
      @url = url_ if url_?
      @protocols = protocols_ if protocols_?
      if (p_url = if _.isFunction @url then @url() else @url)?
        p_protocols = if _.isFunction @protocols
            @protocols()
          else
            @protocols
        @_wsrcConnectGuard = guard =
          Promise.join p_url, p_protocols, (url, protocols) =>
            if @_wsrcConnectGuard == guard
              if url?
                ws = new WebSocket url, protocols
                @_addWebSocket ws, _wsrcConnecting: true
                @emit 'wsrcConnecting', url, protocols
                ws
              else
                @_wsrcNoUrl()
                null
            else
              null
          .catch (error) =>
            @_asyncError error, 'connect'
            @_wsrcReconnect() if @reconnect
            null
      else
        @_wsrcNoUrl()
      @

    _wsrcNoUrl: ->
      @reconnect = false
      @

    _wsrcReconnect: ->
      if @reconnect and !@ws?
        unless @_wsrcTimer?
          if (wait_ms = @_wsrcWait()) > 0
            @_wsrcTimer = setTimeout (@_onWsrcTimer.bind @), wait_ms
            @debug? "reconnect wait #{wait_ms} ms"
          else
            @_wsrcConnect()
      else
        @_wsrcResetTimer()
      @

    _wsrcMaybeReconnect: ->
      if @reconnect
        setImmediate =>
          @_wsrcReconnect()
          null
      @

    _wsrcKill: ->
      @reconnect = false
      if @_wsrcConnecting
        @_wsrcConnecting = false
        @_wsrcResetTimer()
        @emit 'closed'
      null

    _onWsrcTimer: ->
      @_wsrcTimer = null
      if @reconnect and !@ws?
        @_wsrcConnect()
      else
        @_wsrcResetTimer()

    _onWsrcConnect: ->
      @_wsrcWasConnected = true
      @emit 'wsrcConnect'
      null

    _onWsrcReconnect: ->
      @emit 'wsrcReconnect'
      null

  terminate = alien_ws.terminate
  alien_ws.terminate = ->
    @_wsrcKill()
    terminate.apply @, arguments

  close = alien_ws.close
  alien_ws.close = ->
    @_wsrcKill()
    close.apply @, arguments

  alien_ws.on 'wsOpen', ->
            @_wsrcConnecting = false
            @_wsrcResetTimer()
            if @_wsrcWasConnected
              @_onWsrcReconnect()
            else
              @_onWsrcConnect()
            null
          .on 'wsClosed', ->
            @_wsrcMaybeReconnect()
            null

  if connect_url?
    alien_ws.connect connect_url, connect_protocols
  else if alien_ws.ws?
    alien_ws._wsrcWasConnected = true

  alien_ws

module.exports = alienReconnectWs
