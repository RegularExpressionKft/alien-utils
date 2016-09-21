uuid = require 'uuid'
_ = require 'lodash'

AlienWsJson = require './ws-json'

class AlienWs extends AlienWsJson
  # Binary

  ignoreBadBinaryChannel: false

  binaryChannels: @commands null,
    error: (error, cmd, this_object, args) ->
      this_object._onWsaBadBinaryChannel error, args...
    what: 'binary channel id'

  _wsaExtractIdFromBinary: (data) ->
    uuid.unparse data

  _wsaExtractDataFromBinary: (data) ->
    data.slice 16

  _onWsaBadBinaryChannel: (error, msg, data, flags) ->
    if @ignoreBadBinaryChannel
      null
    else
      @_onWsjBadMessage error, msg, data, flags

  _onWsjBinaryMessage: (data, flags) ->
    ch_id = @_wsaExtractIdFromBinary data
    msg = @_wsaExtractDataFromBinary data
    @binaryChannels.call ch_id, @, msg, data, flags

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
