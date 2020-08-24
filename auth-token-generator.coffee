Promise = require 'bluebird'
_ = require 'lodash'

Buffer = require('buffer').Buffer unless Buffer?

auth_utils = require './auth-utils'

class AuthTokenGenerator
  @_nonce: (random, now) ->
    # TODO clock offset / drift handling
    Buffer.concat([ auth_utils.dateBuffer(now), random ]).toString 'hex'

  @syncNonce: (opts) ->
    rnd_length = (opts?.nonceLength ? 16) - auth_utils.dateBufferLength
    random = auth_utils.syncRandomBytes \
      (opts?.nonceLength ? 16) - auth_utils.dateBufferLength
    @_nonce random, opts?.now

  @syncAuthToken: (session, opts) ->
    unless _.isObject(session) and session.id? and session.secret?
      throw new Error 'No session'

    nonce = opts?.nonce ? @syncNonce opts
    hmac = opts?.hmac ? auth_utils.hmac nonce, session.secret, opts

    [ session.id, nonce, hmac ].join ','

  @syncLoginToken: (opts) ->
    auth_utils.syncRandomBytesUrl64 opts?.loginTokenLength ? 32

  @syncSessionSecret: (opts) ->
    auth_utils.syncRandomBytesHex opts?.sessionSecretLength ? 16

  @promiseNonce: (opts) ->
    rnd_length = (opts?.nonceLength ? 16) - auth_utils.dateBufferLength
    auth_utils.promiseRandomBytes rnd_length
              .then (random) => @_nonce random, opts?.now

  @promiseAuthToken: (session, opts) ->
    if _.isObject(session) && session.id? && session.secret?
      p_nonce = if (n = opts?.nonce)?
          if n.then? then n else Promise.resolve n
        else
          @promiseNonce opts
      p_nonce.then (nonce) =>
          hmac = opts?.hmac ? auth_utils.hmac nonce, session.secret, opts

          [ session.id, nonce, hmac ].join ','
    else
      Promise.reject new Error 'No session.'

  @promiseLoginToken: (opts) ->
    auth_utils.promiseRandomBytesUrl64 opts?.loginTokenLength ? 32
    .then (token) =>
      if /^-/.test token
        @promiseLoginToken opts
      else
        token

  @promiseSessionSecret: (opts) ->
    auth_utils.promiseRandomBytesHex opts?.sessionSecretLength ? 16

  constructor: (@session, @opts) ->
    unless _.isObject(@session) and @session.id? and @session.secret?
      throw new Error 'No session'
    return @

  _opts: (opts) ->
    if opts then _.defaults {}, opts, @opts else @opts

  syncNonce: (opts) -> @constructor.syncNonce @_opts opts
  syncAuthToken: (opts) -> @constructor.syncAuthToken @session, @_opts opts

  promiseNonce: (opts) ->
    @constructor.promiseNonce @_opts opts
  promiseAuthToken: (opts) ->
    @constructor.promiseAuthToken @session, @_opts opts

module.exports = AuthTokenGenerator
