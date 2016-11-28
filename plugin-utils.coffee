Promise = require 'bluebird'
require_all = require 'require-all'
_ = require 'lodash'

class PluginUtils
  loadPlugins: (opts) ->
    require_all _.extend
        dirname: "#{process.cwd()}/plugins"
        filter: /^([0-9A-Za-z].*?)\.(?:js|coffee)$/
      , opts

  runPlugins: (plugins = @plugins, run_params...) ->
    start = null
    p_start = new Promise (resolve, reject) ->
      start = resolve
      null

    start plugin_ps = _.mapValues plugins, (plugin) ->
      p_start.then (data) -> plugin data, run_params...

    Promise.props plugin_ps

module.exports = PluginUtils
