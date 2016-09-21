EventEmitter = require 'events'
_ = require 'lodash'

class AlienCommands
  name: null
  what: 'command'

  constructor: (cmds, opts) ->
    _.extend @, opts
    @cmds ?= {}
    @extend cmds if cmds?
    return @

  prefixName: (str, cmd, this_object, args) ->
    if @name?
      name = if _.isFunction @name
          @name cmd, this_object, args
        else
          @name
      "#{name}: #{str}"
    else
      str

  error: (error, cmd, this_object, args) ->
    error = new Error error unless error instanceof Error
    throw error

  missing: (cmd, this_object, args) ->
    @error (@prefixName "Unknown #{@what}: #{cmd}", cmd, this_object, args),
      cmd, this_object, args

  badCmd: (cmd, this_object, args) ->
    @error (@prefixName "Can't execute #{@what}: #{cmd}",
              cmd, this_object, args),
      cmd, this_object, args

  has: (cmd) -> @cmds[cmd]?
  keys: -> _.keys @cmds

  apply: (cmd, this_object, args) ->
    if (f = @cmds[cmd])?
      if f.apply?
        f.apply this_object, args
      else if this_object?[f]?.apply?
        this_object[f].apply this_object, args
      else
        @badCmd cmd, this_object, args
    else
      @missing cmd, this_object, args
  call: (cmd, this_object, args...) -> @apply cmd, this_object, args

  fnApply: (cmd, this_object, args) ->
    if cmd.apply?
      cmd.apply this_object, args
    else
      @apply cmd, this_object, args
  fnCall: (cmd, this_object, args...) -> @fnApply cmd, this_object, args

  extend: (cmds) ->
    for n, v of cmds
      @cmds[n] = if v?.withPrevious? then v.withPrevious @cmds[n] else v
    @

  derive: (cmds, opts) ->
    derived = Object.create @
    derived.cmds = Object.create @cmds
    _.extend derived, opts
    derived.extend cmds

  remove: ->
    cmds = @cmds
    base = Object.getPrototypeOf cmds
    for cmd in _.flatten arguments
      if cmds.hasOwnProperty cmd and !base[cmd]?
        delete cmds[cmd]
      else
        cmds[cmd] = null
    @

class AlienCommander extends EventEmitter
AlienCommander.Commands = AlienCommands
AlienCommander.commands = (cmds, opts) -> new @Commands cmds, opts
AlienCommander.withPrevious = (maker) -> withPrevious: maker

module.exports = AlienCommander
