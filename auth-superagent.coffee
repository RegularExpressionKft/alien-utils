request = require 'superagent'
methods = require 'methods'
_ = require 'lodash'

AuthTokenGenerator = require 'alien-utils/auth-token-generator'

class RequestProxy
  constructor: (p_request) ->
    @promise = p_request.then (request) =>
      request = request.request
      while (q = @_queue.shift())?
        request = request[q.method] q.arguments...
      if request.req?
        # superagent is a promise but doesn't work well bluebird/mocha
        request: request
      else
        # supertest is a promise and works great
        request
    @_queue = []

  queue: (method, args) ->
    @_queue.push
      method: method
      arguments: args
    @
  expect: -> @queue 'expect', arguments
  send: -> @queue 'send', arguments
  end: -> @queue 'end', arguments
  on: -> @queue 'on', arguments

  then: -> @promise.then arguments...
  catch: -> @promise.catch arguments...
  finally: -> @promise.finally arguments...

class AuthSuperagent
  AuthTokenGenerator: AuthTokenGenerator
  RequestProxy: RequestProxy

  constructor: (@_login, opts) ->
    _.defaults @,
      _.pick(opts, [ 'header', 'request' ]),
      header: 'X-Auth', request: request

    if opts?.login
      @login opts
    else
      @_loginOpts opts

    return @

  _loginOpts: (opts) ->
    _.extend @, _.pick opts, [ 'authOpts', 'params' ]

  login: (opts) ->
    @_loginOpts opts
    delete @[prop] for prop in [ 'authTokenGenerator', 'session' ]

    # TODO: error / catch handling?
    @_pAuthTokenGenerator =
      @_login @params, @
      .then (session) =>
        @session = session
        delete @_pAuthTokenGenerator
        @authTokenGenerator = new @AuthTokenGenerator @session, @authOpts

  authenticatedRequest: (method, token, args...) ->
    if !@request[method]?.apply?
      if (method is 'delete') and @request.del?.apply?
        method = 'del'
      else
        throw new Error "Bad request method '#{method}'"
    @request[method](args...).set @header, token

  promiseAuthToken: ->
    if @authTokenGenerator?
      @authTokenGenerator.promiseAuthToken()
    else if @_pAuthTokenGenerator?
      @_pAuthTokenGenerator.then (tg) -> tg.promiseAuthToken()
    else
      @login().then (tg) -> tg.promiseAuthToken()

  authError: ->
    @authTokenGenerator = null
    @

methods.forEach (m) ->
  p = "promise#{m.charAt(0).toUpperCase() + m.substr 1}"
  AuthSuperagent::[p] = (args...) ->
    @promiseAuthToken()
    .then (token) =>
      request: @authenticatedRequest m, token, args...
  AuthSuperagent::[m] = ->
    new @RequestProxy @[p] arguments...

module.exports = AuthSuperagent
