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
  merge_config = (base, current) ->
    if !current?
      base
    else
      cfg =
        if _.isString current
          optional "#{relative_to}/config/#{current}"
        else if _.isFunction current
          current base, user_config, rest...
        else if _.isObject current
          current
        else
          throw new Error "Config '#{current}' is not a string"

      if !cfg?
        base
      else if _.isObject cfg
        _.defaultsDeep cfg, base
      else
        throw new Error "Config '#{current}' is not an object after loading"

  mode =
    if _.isObject user_config
      user_config.mode
    else
      user_config
  order = _.uniq _.flatten [ 'default', mode ? 'dev', 'local', user_config, 'gen' ]

  _.reduce order, merge_config, mode: mode

module.exports = configure
