_ = require 'lodash'

# TODO Move this to a module of its own.
#      Require works relative to the script issuing require.
#      This makes it fairly difficult to make modules that require on
#      behalf of the caller.
optional = (req) ->
  try
    ret = require req
  catch e
    throw e unless (e.code == 'MODULE_NOT_FOUND') &&
                   (("#{e}".indexOf req) >= 0)
  ret

configure = (user_config, relative_to = process.cwd(), rest...) ->
  merge_config = (base, name) ->
    unless _.isString name
      throw new Error "Config name '#{name}' is not a string"

    cfg = optional "#{relative_to}/config/#{name}"
    if _.isFunction cfg
      cfg base, rest...
    else
      _.defaultsDeep cfg, base

  start = {}
  mode =
    if _.isObject user_config
      start = _.cloneDeep user_config
      user_config.mode
    else
      user_config

  order = _.uniq _.flatten [ 'default', mode ? 'dev', 'local', 'gen' ]
  start.mode ?= order[1]

  _.reduce order, merge_config, start

module.exports = configure
