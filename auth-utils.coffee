crypto = require 'crypto'
base64url = require 'base64url'

module.exports =
  dateBufferLength: 6
  dateBuffer: (date) ->
    date_ms = if date?
        if date instanceof Date then date.getTime() else date
      else
        Date.now()
    buffer = Buffer.alloc @dateBufferLength
    buffer.writeUIntBE date_ms, 0, @dateBufferLength
    buffer
  dateHex: (date) -> @dateBuffer(date).toString 'hex'

  hmac: (data, secret, opts) ->
    hmac = crypto.createHmac opts?.hmacHash ? 'sha256', secret
    hmac.update data, 'hex'
    hmac.digest 'hex'

  syncRandomBytes: (n) -> crypto.randomBytes n
  syncRandomBytesHex: (n) -> @syncRandomBytes(n).toString 'hex'
  syncRandomBytesUrl64: (n) -> base64url @syncRandomBytes n

  promiseRandomBytes: (n) ->
    new Promise (resolve, reject) ->
      crypto.randomBytes n, (error, result) ->
        if error? then reject error else resolve result
  promiseRandomBytesHex: (n) ->
    @promiseRandomBytes n
    .then (random) -> random.toString 'hex'
  promiseRandomBytesUrl64: (n) ->
    @promiseRandomBytes n
    # .then (random) -> base64url random
    .then base64url
