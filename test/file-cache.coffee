Promise = require 'bluebird'
child_process = require 'child_process'
destroy = require 'destroy'
assert = require 'assert'
stream = require 'stream'
_ = require 'lodash'

FileCache = require '../file-cache'
pfs = require '../promise-fs'

cache_dir = "#{process.cwd()}/__test-cache__"
cacheType = 'data'

rm_cache = (done) ->
  child_process.exec "rm -rf '#{cache_dir}'",
    (error, stdout, stderr) -> done()

debug_events = (obj, prefix) ->
  emit = obj.emit
  obj.emit = (event) ->
    console.log "EVENT(#{prefix}): #{event}"
    emit.apply @, arguments

check_promise = (cache, entry, state) ->
  served = false
  entry.source = new stream.Readable read: -> null
  # debug_events entry.source, "#{entry.cmd.id}.source"
  cache._promiseLoaderStream = (job) ->
    assert _.isObject(job), 'job is object'
    assert.deepEqual _.omit(job.cmd, 'type'), entry.cmd, 'job.cmd'
    if entry.job?
      assert.strictEqual job, entry.job, 'job equal'
    else
      # debug_events job._proxy, "#{entry.cmd.id}.proxy"
      entry.job = job

    if served
      Promise.reject new Error 'check_promise._promiseLoaderStream re-invoked'
    else
      served = entry.served = true
      Promise.resolve entry.source

  cache.promiseStream entry.cmd.id, entry.cmd
       .then (result) ->
         assert _.isObject(result), 'result is object'
         assert (result.stream instanceof stream.Readable), 'result.stream'
         if entry.job?
           assert.strictEqual result.job, entry.job, 'result.job equal'
         else
           assert _.isObject(job = result.job), 'result.job exists'
           # debug_events job._proxy, "#{entry.cmd.id}.proxy"
           entry.job = job
         assert.equal entry.job.state, state, 'job.state'
         entry.stream = result.stream

check_stream = (entry, text) ->
  new Promise (resolve, reject) ->
    send = Buffer.from "#{text}\n", 'ascii'
    entry.stream.once 'data', (chunk) ->
      try
        assert chunk.equals(send), 'data'
        resolve()
      catch error
        reject error
    entry.source.push send
    entry.content =
      if entry.content? then Buffer.concat [ entry.content, send ] else send

check_finish = (cache, entry) ->
  # stream ouf
  p_eof = new Promise (resolve, reject) ->
    entry.stream.once 'end', ->
      resolve()
  # job finishes
  p_entry = new Promise (resolve, reject) ->
    # TODO remove handler instead of once
    cache.once 'finished', (job) ->
      if job == entry.job
        try
          assert !job.readerFailed, 'reader'
          assert !job.writerFailed, 'writer'
          assert.equal job.size, entry.content.length, 'size'
          resolve()
        catch error
          reject error

  # set in motion
  entry.source.push null

  Promise.join p_eof, p_entry, -> null
         .finally ->
           destroy entry.stream
           delete entry.stream
           destroy entry.source
           delete entry.source

# _.mapToObject?
make_entries = (ids...) ->
  entries = {}
  for id in ids
    entries[id] =
      cmd: id: id
      fn: "#{cache_dir}/#{id}.#{cacheType}"
  entries

describe 'FileCache.Stream', ->
  cache = null
  entries = make_entries 'luck', 'kitten'

  before rm_cache
  after rm_cache

  it 'creates', ->
    cache = new FileCache
      name: 'test'
      maxLoading: 1
      maxFiles: 1
      type: cacheType
    # cache.debug = console.log
    cache.error = console.log

    cache.on 'initialized', ->
      pfs.stat cache_dir
         .then (stat) ->
           assert stat.isDirectory(), 'cache is directory'

  it 'load luck', ->
    check_promise cache, entries.luck, 'loading'

  it 'stream luck', ->
    check_stream entries.luck, 'wild bovine logic depression case'

  it 'queue kitten', ->
    check_promise cache, entries.kitten, 'queued'

  it 'finish luck', ->
    luck = entries.luck
    kitten = entries.kitten

    # luck finishes
    p_finish = check_finish cache, luck

    # kitten job starts loading
    p_kitten = new Promise (resolve, reject) ->
      # TODO remove handler instead of once
      cache.once 'loading', (job) ->
        if job == kitten.job
          try
            assert kitten.served, 'got served'
            resolve()
          catch error
            reject error

    Promise.join p_finish, p_kitten, ->
             pfs.stat luck.fn
           .then (stat) ->
             assert.equal stat.size, luck.job.size, 'data.size'
             null

  it 'loaded luck', ->
    entry = entries.luck
    cache.promiseStream entry.cmd.id, entry.cmd
         .then (result) ->
           assert _.isObject(result), 'result is object'
           assert !result.job?, 'no job, no problem'
           assert.equal result.fn, entry.fn, 'result.fn'
           destroy result.stream
           null

  it 'stream kitten', ->
    check_stream entries.kitten, 'aggressive crowd after sewage essence'

  it 'finish kitten > cleanup', ->
    p_finish = check_finish cache, entries.kitten
    p_cleanup = new Promise (resolve, reject) ->
      # TODO remove handler instead of once
      cache.once 'cleanup', resolve
    Promise.join p_finish, p_cleanup, ->
      p_luck = pfs.stat entries.luck.fn
      p_kitten = pfs.stat entries.kitten.fn
                    .then -> Promise.reject 'kitten should be gone'
                    .catch (error) ->
                      assert (error.code == 'ENOENT'), 'is no longer'
