stream = require 'stream'
_ = require 'lodash'

AlienWsJson = require './ws-json'
uuid = require './uuid'

class AlienWs extends AlienWsJson
  # Binary

  ignoreBadBinaryChannel: false

  binaryChannels: @commands null,
    error: (error, cmd, this_object, args) ->
      this_object._onWsaBadBinaryChannel error, args...
    what: 'binary channel id'

  _wsaMakeBinaryChannelId: (channel_id) ->
    unless channel_id instanceof Buffer
      channel_id = uuid.parse channel_id
    throw new Error 'Bad channel id' unless channel_id.length == 16
    channel_id

  _wsaExtractIdFromBinary: (data) ->
    uuid.unparse data

  _wsaExtractDataFromBinary: (data) ->
    data.slice 16

  _wsaMakeBinaryMessage: (channel_id, data, flags) ->
    channel_id = @_wsaMakeBinaryChannelId channel_id

    if data?
      data = Buffer.from data unless data instanceof Buffer
      Buffer.concat [ channel_id, data ]
    else
      channel_id

  _onWsaBadBinaryChannel: (error, msg, data, flags) ->
    if @ignoreBadBinaryChannel
      null
    else
      @_onWsjBadMessage error, msg, data, flags

  _onWsjBinaryMessage: (data, flags) ->
    channel_id = @_wsaExtractIdFromBinary data
    msg = @_wsaExtractDataFromBinary data
    @debug? "WsBinaryMessage #{channel_id} #{msg.length}"
    @binaryChannels.call channel_id, @, msg, data, flags

  sendOnBinaryChannel: (channel_id, data, flags, cb) ->
    if !cb? and _.isFunction flags
      cb = flags
      flags = null
    @sendBinary @_wsaMakeBinaryMessage(channel_id, data, flags), flags, cb

  _wsaSetupStream: (destroyer, strm) ->
    strm.wsaRunning = true

    forward_error = (error) ->
      if strm.wsaRunning and strm.listenerCount('error') > 0
        strm.emit 'error', error
      null

    orig_destroy = strm.destroy
    strm.destroy = =>
      if strm.wsaRunning
        strm.wsaRunning = false
        @removeListener 'wsError', forward_error
        destroyer 'destroy'
      if orig_destroy?
        orig_destroy.apply strm, arguments
      else
        strm

    @on 'wsError', forward_error

    strm

  createReadStream: (channel_id, cleanup, stream_options) ->
    channel_id = @_wsaMakeBinaryChannelId channel_id
    channel_id_str = @_wsaExtractIdFromBinary channel_id

    rstream = new stream.Readable _.defaults (read: ->), stream_options
    rstream.wsaEof = false

    destroyer = (cause) =>
      unless rstream.wsaEof
        rstream.wsaEof = true
        rstream.push null
      cleanup? @, channel_id_str, rstream, cause
      null

    @binaryChannels.add channel_id_str, (msg) ->
      msg_ = if msg?.length > 0 then msg else null
      rstream.push msg_ if rstream.wsaRunning

      unless msg_?
        rstream.wsaEof = true
        @binaryChannels.remove channel_id_str
        destroyer 'eof'

      null

    @_wsaSetupStream destroyer, rstream

  createWriteStream: (channel_id, cleanup, stream_options) ->
    channel_id = @_wsaMakeBinaryChannelId channel_id
    channel_id_str = @_wsaExtractIdFromBinary channel_id

    wstream = new stream.Writable _.defaults
        write: (data, encoding, cb) =>
          if wstream.wsaRunning
            if @open
              @sendOnBinaryChannel channel_id, data, null, cb
            else
              error = new Error 'WebSocket not open'
              if cb? then cb error else wstream.emit 'error', error
          null
      , stream_options
    destroyer = (cause) =>
      if @open
        @sendOnBinaryChannel channel_id, null
      else
        wstream.emit 'error', new Error 'WebSocket not open'
      cleanup? @, channel_id_str, wstream, cause
      null
    wstream.on 'finish', -> destroyer 'eof'

    @_wsaSetupStream destroyer, wstream

  # JSON

  ignoreBadMessageType: false

  messageTypes: @commands null,
    error: (error, cmd, this_object, args) ->
      this_object._onWsaBadMessageType error, args...
    what: 'type'

  _onWsaBadMessageType: (error, msg, data, flags) ->
    if @ignoreBadMessageType
      null
    else
      @_onWsjBadMessage error, msg, data, flags

  _onWsjJsonMessage: (msg, data, flags) ->
    @debug? 'WsJsonMessage', msg
    if (_.isObject msg) && (_.isString msg.type)
      @messageTypes.call msg.type, @, msg, data, flags
    else
      @_onWsBadMessageType 'Bad / no type.', msg, data, flags
    null

add_cmds = (obj, what, cmds) ->
  if obj.hasOwnProperty what
    obj[what].extend cmds
  else
    obj[what] = obj[what].derive cmds
  obj
remove_cmds = (obj, what, cmds) ->
  if obj.hasOwnProperty what
    obj[what].extend()
  else
    obj[what] = obj[what].derive()
  obj[what].remove cmds
  obj
_.each
    messageTypes: 'MessageType'
    binaryChannels: 'BinaryChannel'
  ,
    (name_stem, cmdr_key) ->
      adder = "add#{name_stem}"
      adders = "#{adder}s"
      remover = "remove#{name_stem}"
      AlienWs[adders] ?= (cmds) ->
        add_cmds @::, cmdr_key, cmds
        @
      AlienWs[adder] ?= (cmd, cb) ->
        add_cmds @::, cmdr_key, "#{cmd}": cb
        @
      AlienWs[remover] ?= ->
        remove_cmds @::, cmdr_key, _.flatten arguments
        @
      AlienWs::[adders] ?= (cmds) ->
        add_cmds @, cmdr_key, cmds
      AlienWs::[adder] ?= (cmd, cb) ->
        add_cmds @, cmdr_key, "#{cmd}": cb
      AlienWs::[remover] ?= ->
        remove_cmds @, cmdr_key, _.flatten arguments

module.exports = AlienWs
