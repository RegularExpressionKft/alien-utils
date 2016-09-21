assert = require 'assert'
stream = require 'stream'

StreamProxy = require '../stream-proxy'

check_reader = (proxy, reader) ->
  assert reader?, 'creates reader'
  assert (reader instanceof proxy.Reader), 'reader ISA proxy.Reader'
  assert (reader instanceof stream.Readable), 'reader ISA stream.Readable'
  true

check_chunk = (chunk, expected, done) ->
  assert (chunk instanceof Buffer), 'chunk is buffer'
  got = chunk.toString 'ascii'
  assert.equal got, expected, 'chunk is good'
  done()

check_chunk_once = (reader, expected, done) ->
  reader.once 'data', (chunk) ->
    check_chunk chunk, expected, done

promise_check_chunk = (reader, expected) ->
  new Promise (resolve, reject) ->
    check_chunk_once reader, expected, resolve

describe 'StreamProxy', ->
  describe 'Buffer Mode', ->
    source = new stream.Readable
      read: -> null
    sent = ''

    proxy = null
    reader1 = null
    reader2 = null

    it 'instantiates', (done) ->
      proxy = new StreamProxy
      assert proxy?, 'proxy created'
      assert (proxy instanceof StreamProxy), 'proxy ISA StreamProxy'
      assert (proxy instanceof stream.Writable), 'proxy ISA stream.Writable'
      done()

    it 'accepts input', (done) ->
      source.pipe proxy
      done()

    it 'creates reader1', (done) ->
      reader1 = proxy.createReader()
      check_reader proxy, reader1
      done()

    it 'data > reader1', (done) ->
      send = 'alma'
      check_chunk_once reader1, send, done
      source.push Buffer.from send, 'ascii'
      sent = sent + send

    it 'creates reader2', (done) ->
      reader2 = proxy.createReader()
      check_reader proxy, reader2
      done()

    it 'data > reader2', (done) ->
      check_chunk_once reader2, sent, done

    it 'data > [reader1, reader2]', ->
      send = 'barac'
      p1 = promise_check_chunk reader1, send
      p2 = promise_check_chunk reader2, send
      source.push Buffer.from send, 'ascii'
      sent = sent + send
      Promise.all [p1, p2]

    it 'finish > [reader1, reader2]', ->
      check_chunk_once reader1
      check_chunk_once reader2
      ps = [reader1, reader2].map (reader) ->
        new Promise (resolve, reject) ->
          reader.once 'end', resolve
      source.push null
      Promise.all ps
