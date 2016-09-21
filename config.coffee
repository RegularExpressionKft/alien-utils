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

load_config = (name, relative_to = process.cwd(), rest...) ->
  cfg = optional "#{relative_to}/config/#{name}"
  cfg = cfg rest... if _.isFunction cfg
  cfg

configure = (user_config, relative_to = process.cwd()) ->
  default_config = load_config 'default', relative_to
  local_config = load_config 'local', relative_to
  tmp_config = _.defaultsDeep {}, user_config, local_config

  mode = tmp_config.mode ?= default_config?.mode ? 'dev'
  unless mode.match /^(?:default|local)$/
    mode_config = load_config mode, relative_to

  _.defaultsDeep tmp_config, mode_config, default_config

configure.loadConfig = load_config

module.exports = configure
