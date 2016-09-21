request = require 'superagent'

AlienWsClient = require '../ws-client'
alienReconnectWs = require '../ws-reconnect'

server = 'localhost:6543'
channel = 'alma'

ws = alienReconnectWs new AlienWsClient
ws.debug = -> console.log "ws:", arguments...
ws.subscribe channel
ws.on "subscribed:#{channel}", ->
  console.log 'subscribed'
  request.post "http://#{server}/api/push/#{channel}"
         .send content: 'hello'
         .end (error, result) ->
           console.log 'http finished',
             error: error
             result: result
           null
ws.on 'event', (msg) ->
  console.log 'event', msg
  null
ws.connect "ws://#{server}/realtime"
