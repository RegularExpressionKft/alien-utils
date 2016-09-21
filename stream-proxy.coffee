stream = require 'stream'
_ = require 'lodash'

class StreamProxyReader extends stream.Readable
  defaultChunkSize: 16384

  constructor: (@master) ->
    @reading = false
    @finished = false
    @position = 0

    super @_superOptions()

    @onMaster 'proxy_data', @_onMasterData
    @onMaster 'proxy_finish', @_onMasterFinish
    @onMaster 'proxy_error', @_onMasterError

    return @

  _superOptions: ->
    opts = _.omit @master.options, ['read']
    if _.has opts, 'readHighWaterMark'
      opts.highWaterMark = opts.readHighWaterMark
    opts

  onMaster: (event, listener) ->
    @masterListeners ?= {}
    @masterListeners[event] ?= []
    @masterListeners[event].push listener
    @master.on event, listener
    @
  removeMasterListener: (event, listener) ->
    if (idx = _.find @masterListeners[event], (x) -> x == listener)?
      if idx > 0 or @masterListeners[event].length > 1
        @masterListeners[event].splice idx, 1
      else
        delete @masterListeners[event]
    @master.removeListener event, listener
    @

  removeAllMasterListeners: ->
    for event, listeners of @masterListeners
      for listener in listeners
        @master.removeListener event, listener
    delete @masterListeners
    @

  close: ->
    @_done()
    @emit 'close'

  _onMasterData: =>
    @_push null if @reading
    null

  _onMasterFinish: =>
    @_push null if @reading
    null

  _onMasterError: (error) =>
    @emit 'error', error
    null

  # May get called recursively, yay!
  _push: (size) ->
    push = true
    unless @_inPush
      try
        if (buffer = @master.buffer)?
          @_inPush = true
          if @master.options.objectMode
            while push and @position < buffer.length
              push = @push buffer[@position]
              @position++
          else
            while push and @position < buffer.length
              to_read = buffer.length - @position
              to_read = size if (size ? @defaultChunkSize) < to_read
              push = @push buffer.slice @position, @position + to_read
              @position += to_read
          @_inPush = false

          if push
            @_done() if @master.finished and @position >= buffer.length
          else
            @reading = false
      catch error
        @_inPush = false
        throw error
    push

  _read: (size) ->
    @reading = true
    @_push size
    null

  _done: ->
    @reading = false
    @removeAllMasterListeners()
    unless @finished
      @push null
      @finished = true
    null

class StreamProxy extends stream.Writable
  constructor: (options_in) ->
    @finished = false
    @length = 0

    @options = _.defaults
        decodeStrings: true
        objectMode: false
      , options_in
    super @_superOptions()

    @on 'error', @_onError
    @on 'close', @_onClose
    @on 'finish', @_onFinish

    return @

  Reader: StreamProxyReader
  createReader: -> new @Reader @

  _done: ->
    @finished = true
    @emit 'proxy_finish'
  _onError: (error) -> @emit 'proxy_error', error
  _onClose: -> @_done()
  _onFinish: -> @_done()

  _superOptions: ->
    opts = _.omit @options, ['write', 'writev']
    if _.has opts, 'writeHighWaterMark'
      opts.highWaterMark = opts.writeHighWaterMark
    opts

  _pushObject: (chunk) ->
    if @buffer?
      if @buffer instanceof Array
        @length = @buffer.push chunk
        null
      else
        new Error 'In object mode but @buffer is not an Array.'
    else
      @buffer = [chunk]
      @length = 1
      null

  _pushBuffer: (chunk) ->
    if @buffer?
      if @buffer instanceof Buffer
        # This seems horribly inefficient
        # http://www.joelonsoftware.com/articles/fog0000000319.html
        @buffer = Buffer.concat [
          @buffer,
          if chunk instanceof Buffer then chunk else Buffer.from chunk ]
        @length = @buffer.length
        null
      else
        new Error 'In buffer mode but @buffer is not a Buffer.'
    else
      @buffer = Buffer.from chunk
      @length = @buffer.length
      null

  _write: (chunk, encoding, callback) ->
    error = if @options.objectMode
        @_pushObject chunk
      else
        @_pushBuffer chunk
    @emit 'proxy_data' unless error?
    callback error

module.exports = StreamProxy
