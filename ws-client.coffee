_ = require 'lodash'

AlienWs = require './ws-alien'

# TODO subscribed_all event
class AlienWsClient extends AlienWs
  constructor: ->
    ret = super
    @_wscSubscribed = {}
    @_wscUnsubscribed = {}
    return ret

  subscribe: (channel_ids...) ->
    [not_really, really] =
      _.partition _.flatten(channel_ids), (c) => @_wscSubscribed[c]?
    @_onWscFalseSubscribed not_really if not_really.length > 0
    if really.length > 0
      @_wscSubscribed[c] = false for c in really
      @_wscSendSubscribe really if @open
    @

  unsubscribe: (channel_ids...) ->
    [really, not_really] =
      _.partition _.flatten(channel_ids), (c) => @_wscSubscribed[c]?
    @_onWscFalseUnsubscribed not_really if not_really.length > 0
    if really.length > 0
      for c in really
        @_wscUnsubscribed[c] = true
        delete @_wscSubscribed[c]
      @_wscSendUnsubscribe really if @open
    @

  # Event handlers

  messageTypes: @::messageTypes.derive
    event: '_onWscEvent'
    subscribed: '_onWscSubscribedResponse'
    unsubscribed: '_onWscUnsubscibedResponse'

  _onWsOpen: ->
    ret = super
    @_wscSendSubscribe _.keys @_wscSubscribed
    ret

  _onWsClose: ->
    ret = super
    unless _.empty @_wscUnsubscribed
      channel_ids = _.keys @_wscUnsubscribed
      @_wscUnsubscribed = {}
      @_onWscTrueUnsubscribed channel_ids
    ret

  _onWsaBadMessageType: -> null

  _onWscEvent: (msg) ->
    @emit 'event', msg
    null

  # subscribe

  _onWscSubscribedResponse: (msg) ->
    if _.isArray(msg.channels) and msg.channels.every _.isString
      grouped = _.groupBy msg.channels, (c) =>
        if (s = @_wscSubscribed[c])?
          if s
            'dupe'
          else
            'genuine'
        else
          'surprise'
      if grouped.genuine
        @_wscSubscribed[c] = true for c in grouped.genuine
        @_onWscTrueSubscribed grouped.genuine
      @_onWscSurpriseSubscribed grouped.surprise if grouped.surprise
    null

  _onWscTrueSubscribed: (channel_ids) -> @_onWscSubscribed channel_ids
  _onWscFalseSubscribed: (channel_ids) -> @_onWscSubscribed channel_ids
  _onWscSurpriseSubscribed: (channel_ids) -> @_onWscSubscribed channel_ids
  _onWscSubscribed: (channel_ids) ->
    @emit 'subscribed', channel_ids
    @emit "subscribed:#{c}" for c in channel_ids
    null

  _wscSendSubscribe: (channel_ids) ->
    if channel_ids.length
      @sendJSON
        type: 'subscribe'
        channels: channel_ids
    @

  # unsubscribe

  _onWscUnsubscribedResponse: (msg) ->
    if _.isArray(msg.channels) and msg.channels.every _.isString
      grouped = _.groupBy msg.channels, (c) =>
        if @_wscUnsubscribed[c]
          'genuine'
        else if @_wscSubscribed[c]?
          'surprise'
        else
          'fake'
      if grouped.genuine
        delete @_wscUnsubscribed[c] for c in grouped.genuine
        @_onWscTrueUnsubscribed grouped.genuine
      @_onWscSurpriseUnsubscribed grouped.surprise if grouped.surprise
      @_onWscFakeUnsubscribed grouped.fake if grouped.fake
    null

  _onWscTrueUnsubscribed: (channel_ids) -> @_onWscUnsubscribed channel_ids
  _onWscFalseUnsubscribed: (channel_ids) -> @_onWscUnsubscribed channel_ids
  _onWscSurpriseUnsubscribed: (channel_ids) -> @_onWscUnsubscribed channel_ids
  _onWscFakeUnsubscribed: (channel_ids) -> @_onWscUnsubscribed channel_ids
  _onWscUnsubscribed: (channels) ->
    @emit 'unsubscribed', channels
    @emit "unsubscribed:#{c}" for c in channels
    null

  _wscSendUnsubscribe: (channel_ids) ->
    if channel_ids.length
      @sendJSON
        type: 'unsubscribe'
        channels: channel_ids
    @

module.exports = AlienWsClient
