winston = require 'winston'
util = require 'util'
uuid = require 'uuid'
_ = require 'lodash'

class AlienLogger
  constructor: (id = uuid.v4(), @level) ->
    if id.match /^[0-9a-f]{8}-?(?:[0-9a-f]{4}-?){3}[0-9a-f]{12}$/
      @id = new Buffer(id.replace /[^0-9a-f]/ig, '')
        .toString('base64')
        .replace /\=/g, ''
      @shortid = @id.substr 0, 6
      @prefix = '«' + @shortid + '»'
    else
      @id = id
      @prefix = '«' + @id + '»'

    self = @
    @master = @constructor.logger
    @levels = @master.levels
    (_.keys @levels).forEach (level) =>
      @[level] ?= ->
        self.log level, arguments...
        @

    @

  _prefixize: (args) ->
    args = [].slice.call args unless _.isArray args
    if _.isString args[0]
      args[0] = @prefix + args[0]
    else
      args.unshift @prefix
    args

  log: (level, rest...) ->
    if !@level? or
       ((@levels[@level] ? @level) >= (@levels[level] ? level))
      args = @_prefixize rest
      args.unshift level
      @master.log args...
    @

  decorate: (object) ->
    logger = object.logger ?= @
    object[level] ?= logger[level] for level in _.keys logger.levels
    object

  @formatters:
    format: (options) ->
      (@formatTimestamp options) +
      (@formatPrefix options) +
      (@formatLevel options) +
      (@formatMessage options) +
      (@formatMeta options)

    formatTimestamp: (options) ->
      if _.isFunction options.timestamp
        options.timestamp() + ' '
      else
        ''

    formatPrefix: (options) ->
      if options.message? && match = options.message.match /^«(.*?)»/
        options.message = options.message.substring match[0].length
        match[1] + ' '
      else
        '------ '

    formatLevel: (options) ->
      if options.colorize
        (winston.config.colorize options.level, options.level.toUpperCase()) +
          ' '
      else
        options.level.toUpperCase() + ' '

    formatMessage: (options) -> options.message ? ''

    formatMeta: (options) ->
      (if options.meta && Object.keys(options.meta).length > 0
        "\n" + util.inspect(options.meta, depth: null)
      else
        '').replace /\n(?=.)/g, "\n\t"

  @boundFormatter: @formatters.format.bind @formatters

  @init: (master_id, config) ->
    if _.isObject(master_id) and !config?
      config = master_id
      master_id = null
    config = mode: config if _.isString config
    config ?= {}
    master_id ?= config.masterId ? '------'

    if !@logger?
      transports = []
      if config.console ? true
        transports.push new winston.transports.Console
          name: 'console'
          formatter: AlienLogger.boundFormatter
          colorize: true
      if config.path?
        transports.push new winston.transports.File
          name: 'logfile'
          timestamp: -> (new Date).toISOString()
          filename: config.path
          formatter: AlienLogger.boundFormatter
          json: false

      @logger = new winston.Logger
        transports: transports

      if config?.level?
        @logger.level = config.level
      else if config?.mode == 'dev'
        @logger.level = 'silly'
      else if config?.mode == 'test'
        @logger.transports.console?.level = 'warn'
        @logger.transports.logfile?.level = 'silly'
      else
        @logger.transports.console?.level = 'warn'
        @logger.transports.logfile?.level = 'info'

    new @ master_id

module.exports = AlienLogger
