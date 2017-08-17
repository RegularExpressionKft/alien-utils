Promise = require 'bluebird'
require_all = require 'require-all'
assert = require 'assert'
_ = require 'lodash'

runPlugins = (plugins, args...) ->
    start = null
    p_start = new Promise (resolve, reject) ->
      start = resolve
      null

    context = @
    start plugin_ps = _.mapValues plugins, (plugin) ->
      p_start.then (data) -> plugin.apply context, [ data ].concat args

    Promise.props plugin_ps

class PluginUtils
  @runPlugins: runPlugins

  loadPlugins: (opts) ->
    require_all _.extend
        dirname: "#{process.cwd()}/plugins"
        filter: /^([0-9A-Za-z].*?)\.(?:js|coffee)$/
      , opts

  runPlugins: (plugins = @plugins, run_params...) ->
    runPlugins.apply @, [ plugins ].concat run_params

  patch: (action, plugin, handler) ->
    assert _.isString(action), 'action is string'
    assert _.isString(plugin), 'plugin is string'
    assert _.isFunction(handler), 'handler is function'
    ((@_patches ?= {})[action] ?= {})[plugin] = handler
    @

  pluggableAction: (action, args...) ->
    assert _.isString(action), 'action is string'
    if _.isEmpty(plugins = @_patches?[action])
      Promise.resolve null
    else
      runPlugins.apply @, [ plugins, action ].concat args

module.exports = PluginUtils
