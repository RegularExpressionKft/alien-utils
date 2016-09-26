Promise = require 'bluebird'
_ = require 'lodash'
methods = require 'methods'
request = require 'superagent'

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

  constructor: (@_login, opts = {}) ->
    _.defaults @, opts, header: 'X-Auth', request: request
    return @

  login: (opts = {}) ->
    _.extend @, _.pick opts, [ 'authOpts', 'params' ]
    delete @[prop] for prop in [ 'authTokenGenerator', 'session' ]

    @_pAuthTokenGenerator =
      @_login @params, @
      .then (session) =>
        @session = session
        delete @_pAuthTokenGenerator
        @authTokenGenerator = new @AuthTokenGenerator @session, @authOpts
      .catch (error) =>
        # TODO
        console.log error

  authenticatedRequest: (method, token, args...) ->
    if !@request[method]?.apply?
      if (method is 'delete') and @request.del?.apply?
        method = 'del'
      else
        throw new Error "Bad request method '#{method}'"
    @request[method](args...).set @header, token

methods.forEach (m) ->
  p = "promise#{m.charAt(0).toUpperCase() + m.substr 1}"
  AuthSuperagent::[p] = (args...) ->
    p_token = if @authTokenGenerator?
        @authTokenGenerator.promiseAuthToken()
      else if @_pAuthTokenGenerator?
        @_pAuthTokenGenerator.then (tg) => tg.promiseAuthToken()
      else
        @login().then (tg) => tg.promiseAuthToken()
    p_token.then (token) =>
      request: @authenticatedRequest m, token, args...
  AuthSuperagent::[m] = ->
    new @RequestProxy @[p] arguments...

module.exports = AuthSuperagent
