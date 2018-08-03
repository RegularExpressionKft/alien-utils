uuid = require 'uuid'

re_uuid = /^[0-9a-f]{8}(?:-?[0-9a-f]{4}){3}-?[0-9a-f]{12}$/i

alien_uuid =
  v4: uuid.v4
  regexp: re_uuid
  test: (x) -> re_uuid.test x

  parse: (x) ->
    unless x instanceof Buffer
      x =
        if _.isString(x) and
           (x.length == 32 or x.length == 36)
          Buffer.from x.replace(/-/g, ''), 'hex'
        else
          Buffer.from x
    throw new Error 'Bad channel id' unless x.length == 16
    x

  unparse: (x) ->
    x = x.toString 'hex' if x instanceof Buffer
    if !_.isString(x) or (x.length != 32)
      throw new Error "Can't unparse '#{x}'"
    "#{x.slice 0, 8}-#{x.slice 8, 12}-#{x.slice 12, 16}-#{x.slice 16, 20}-#{x.slice 20}"

module.exports = alien_uuid
