EventEmitter = require 'events'
Promise = require 'bluebird'
destroy = require 'destroy'
crypto = require 'crypto'
uuid = require 'uuid'
fs = require 'fs'
_ = require 'lodash'

StreamProxy = require './stream-proxy'
TaskRunner = require './task-runner'
pfs = require './promise-fs'
file_utils = require './file-utils'

underscore = "_"[0]

class CacheMissError extends Error then constructor: -> super

# TODO Get rid of callbacks, use promises everywhere
class FileCache extends EventEmitter
  defaults:
    maxLoading: 3
    maxFiles: 1000
    maxBytes: 104857600 # 100MB
    # directory: "#{process.cwd()}/__cache__"
    digest: 'sha256'

  constructor: (options) ->
    @options = _.defaults options, @defaults, file_utils.defaults
    @options.directory ?= process.cwd() + '/' +
      if @options.name? then "__#{@options.name}-cache__" else '__cache__'
    @options.tmpDirectory ?= "#{@options.directory}/__tmp__"
    @options.tmpDirMode ?= @options.dirMode

    @MissError = CacheMissError
    @_loading = {}
    @_queued = []

    @_init()

    return @

  _createMiss: (reason = 'Cache miss') => new @MissError reason
  _rejectMiss: (reason = 'Cache miss') => Promise.reject @_createMiss reason
  isMiss: (error) => error instanceof @MissError

  _returnJob: (job) ->
    Promise.resolve
      stream: job._proxy.createReader()
      job: job

  _logJob: (job) ->
    _.omitBy job, (v, k) -> k[0] == underscore

  _tagToFn: (tag, ext) ->
    @options.directory + '/' + tag + if ext? then ".#{ext}" else ''

  # ==== INIT

  _init: ->
    pfs.mkdir @options.directory, @options.dirMode
       .catch file_utils.isEexist, -> null
       .then => pfs.mkdir @options.tmpDirectory, @options.tmpDirMode
       .catch file_utils.isEexist, -> null
       .then =>
         @emit 'initialized'
         @_loadCache()
         null

  # ==== CLEAN

  _loadCache: ->
    @_scanning ?= pfs.glob "#{@options.directory}/*.data"
                     .then (files) =>
                       @_loadCachedFiles files
                     .catch (error) =>
                       @error? 'loadCache/glob', error
                       null

  _loadCachedFile: (fn) ->
    if (match = fn.match /([^/]+)\.data$/)?
      result = tag: match[1]
      pfs.stat fn
         .then (stat) ->
           result.size = stat.size
           fn = fn.replace /\.data$/, '.lru'
           pfs.stat fn
         .then (stat) ->
           result.lru = stat.mtime
           result
         .catch (error) =>
           @error? "stat(#{fn})", error
           null
    else
      Promise.resolve null

  _loadCachedFiles: (files) ->
    Promise.map files, ((fn) => @_loadCachedFile fn), concurrency: 1
           .then (results) =>
             cache = {}
             cache[r.tag] = r for r in results when r?

             if @_cache?
               _.extend @_cache, cache
             else
               @_cache = cache
             @sizeBytes = _.reduce @_cache, ((s, c) -> s + c.size), 0
             @sizeN = _.size @_cache

             @_scanning = null
             @emit 'reload'

             @_cleanupCache()
             null

  _removeOneFromCache: (tag) ->
    base = @_tagToFn tag
    pfs.unlink "#{base}.data"
       .catch (error) ->
         @error? 'unlink data', error unless file_utils.isEnoent error
         null
       .then -> pfs.unlink "#{base}.meta"
       .catch (error) ->
         @error? 'unlink meta', error unless file_utils.isEnoent error
         null
       .then -> pfs.unlink "#{base}.lru"
       .catch (error) ->
         @error? 'unlink lru', error unless file_utils.isEnoent error
         null

  _removeManyFromCache: (tags) ->
    Promise.map tags, ((tag) => @_removeOneFromCache tag), concurrency: 1
           .catch (error) =>
             @error? 'removeManyFromCache', error
             null
           .then -> tags

  _removeFromCache: (tags) ->
    if _.isArray tag
      @_removeManyFromCache tags
    else
      @_removeOneFromCache tags
      .then -> [tags]

  _cleanupCache: ->
    if @_cache? and @sizeN?
      to_remove = []
      tags_lru = _.keys(@_cache).sort (a, b) =>
                   @_cache[a].lru - @_cache[b].lru
      size_n_after = @sizeN
      size_b_after = @sizeBytes

      while tags_lru.length > 0 and
            (size_n_after > @options.maxFiles or
             size_b_after > @options.maxBytes)
        size_b_after -= @_cache[tags_lru[0]].size
        size_n_after--
        to_remove.push tags_lru.shift()

      if to_remove.length > 0
        if @debug?
          dump =
            __size_n_before: @sizeN
            __size_b_before: @sizeBytes
            __size_n_after: size_n_after
            __size_b_after: size_b_after
          _.extend dump, _.pick @_cache, to_remove
          @debug 'cleanup', dump

        @_cache = _.omit @_cache, to_remove
        @sizeBytes = _.reduce @_cache, ((s, c) -> s + c.size), 0
        @sizeN = _.size @_cache

        @_removeManyFromCache to_remove
        .then => @emit 'cleanup', to_remove
      else
        @emit 'cleanup', to_remove
        Promise.resolve to_remove
    else
      Promise.resolve null

  # ==== ADD

  _getMeta: (job) ->
    meta = _.defaults job.meta,
      cmd: job.cmd
      date: job.now
      size: job.size
    meta[@options.digest] ?= job.digest if @options.digest? and job.digest?
    meta

  _writeMeta: (job) ->
    Promise.resolve @_getMeta job
           .then (meta) =>
             fn = @_tagToFn job.tag, 'meta'
             file_utils.promiseWriteJson fn, meta, mode: @options.fileMode
           .then -> true
           .catch (error) =>
             @error? 'writeMeta',
               error: error
               job: @_logJob job
             false

  # TODO job_or_tag + errors
  _updateLru: (job_or_tag) ->
    tag = if _.isString job_or_tag then job_or_tag else job_or_tag.tag
    now = job_or_tag.now ? new Date
    fn = @_tagToFn tag, 'lru'
    @_cache?[tag]?.lru = now

    pfs.utimes fn, now, now
       .catch file_utils.isEnoent, =>
         pfs.writeFile fn, '', mode: @options.fileMode
            .then -> pfs.utimes fn, now, now
            .then -> true
       .catch (error) =>
         @error? "updateLru(#{tag})", error
         false

  _addToCache: (job) ->
    TaskRunner.promise
                writeMeta: => @_writeMeta job
                updateLru: => @_updateLru job
              .catch (errors) =>
                @error? 'addToCache:', errors
                null
              .then =>
                unless @_cache?[job.tag]?
                  @_cache ?= {}
                  @_cache[job.tag] =
                    size: job.size
                    lru: job.now
                    tag: job.tag
                  @sizeBytes =
                    if @sizeBytes? then @sizeBytes + job.size else job.size
                  @sizeN = if @sizeN? then @sizeN + 1 else 1

                  @_cleanupCache()
                null

  # ==== LOADER

  # implement this:
  # _promiseLoaderStream: (job) -> Promise.resolve readable_stream

  _cleanupLoader: (job) ->
    if job._loaderStream?
      destroy job._loaderStream
      delete job._loaderStream
    Promise.resolve null

  _onLoaderFinished: (job, error) ->
    if error?
      @error? 'Loader failed',
        error: error
        errorStr: "#{error}"
        job: @_logJob job
      job.loaderState = 'error'
      job.loaderFailed = true
    else
      @debug? 'Loader done', @_logJob job
      job.loaderState = 'done'
      job.size = job._proxy.length
    job.loaderFinished = true
    @_onJobMaybeFinished job

  _addLoaderStream: (job, stream_or_buffer) ->
    if stream_or_buffer instanceof Buffer
      buffer = stream_or_buffer
      @debug? 'Loader returned buffer', @_logJob job
      job.loaderState = 'running'
      job._proxy.end buffer
      @_onLoaderFinished job
    else
      stream = stream_or_buffer
      @debug? 'Started loader', @_logJob job
      job.loaderState = 'running'
      job._loaderStream = stream
      stream.on 'error', (error) => @_onLoaderFinished job, error
            .on 'end', => @_onLoaderFinished job
            .pipe job._proxy
    @

  _setupLoader: (job) ->
    @debug? 'Starting loader', @_logJob job
    job.loaderState = 'starting'
    @_promiseLoaderStream job
    .then (stream) => @_addLoaderStream job, stream
    .catch (error) => @_onLoaderFinished job, error

  # ==== WRITER
  # Save a source stream to a temporary file.
  # Move to cache dir.
  # metadata, lru
  # Failure -> rm tmp, no add
  # Failure doesn't kill cache job immediately.

  _cleanupWriter: (job) ->
    if job._writerStream?
      destroy job._writerStream
      delete job._writerStream

      if job.loaderFailed or job.writerFailed
        pfs.unlink job.tmpFn
           .catch (error) =>
             @error? 'unlink tmp', error unless file_utils.isEnoent error
             null
           .then => @_removeOneFromCache job.tag
      else
        Promise.resolve null
    else
      Promise.resolve null

  _onWriterFinished: (job, error) ->
    if error?
      @error? 'Writer failed',
        error: error
        job: @_logJob job
      job.writerFinished = true
      job.writerFailed = true
      @_onJobMaybeFinished job
    else if job.loaderFailed
      @debug? 'Writer done, loader failed, not moving', @_logJob job
      job.writerFinished = true
      @_onJobMaybeFinished job
    else
      @debug? 'Writer done, moving', @_logJob job
      pfs.rename job.tmpFn, fn = @_tagToFn job.tag, 'data'
         .then =>
           job.fn = fn
           @debug? 'Rename finished, writer success', @_logJob job
         .catch (error) =>
           @error? 'Rename failed',
             error: error
             job: @_logJob job
           job.writerFailed = true
           null
         .then =>
           job.writerFinished = true
           @_onJobMaybeFinished job
    null

  _setupWriter: (job) ->
    try
      job.tmpFn ?= "#{@options.tmpDirectory}/#{uuid.v4()}"
      @debug? 'Starting writer', @_logJob job
      job._writerStream = writer =
        fs.createWriteStream job.tmpFn, mode: @options.fileMode
      source = job._proxy.createReader()
      if @options.digest?
        job._writerDigest = hash = crypto.createHash @options.digest
        source.on 'data', (chunk) -> hash.update chunk
              .on 'end', -> job.digest ?= hash.digest 'hex'
      writer.on 'close', => @_onWriterFinished job
            .on 'error', (error) => @_onWriterFinished job, error
      source.pipe writer
      @
    catch error
      @_onWriterFinished job, error

  # ==== LOAD
  # Load data for a tag

  _promiseLoading: (tag) ->
    if (loading = @_loading[tag])?
      @_returnJob loading
    else
      @_rejectMiss()

  _onJobFinished: (job) ->
    job.finished = true
    if job.loaderFailed
      job.state = 'failed'
      job.failed = true
      @emit 'failed', job
    else
      # writer may have failed, but was loaded ok
      job.state = 'finished'
      @emit 'loaded', job
    delete @_loading[job.tag]
    @debug? 'Job done', @_logJob job

    TaskRunner.promise
                loader: => @_cleanupLoader job
                writer: => @_cleanupWriter job
              .catch (errors) =>
                @error? 'onJobFinished:', errors
                null
              .then =>
                unless job.writerFailed
                  @_addToCache job
                  .catch (error) =>
                    @error? 'addToCache', error
                    null
              .finally =>
                @emit 'finished', job
                @_runQueue()

  _onJobMaybeFinished: (job) ->
    if job.loaderFailed or
       (job.loaderFinished and job.writerFinished)
      @_onJobFinished job unless job.finished
    null

  _loadJob: (job) ->
    job.state = 'loading'
    @_loading[job.tag] = job
    @debug? 'Loading job', @_logJob job
    @_setupWriter job
    @_setupLoader job
    @emit 'loading', job
    job

  _promiseLoadingJob: (job) ->
    @_loadJob job
    @_returnJob job

  # ==== QUEUE
  # Queue jobs if too many loaders are running

  _promiseQueued: (tag) ->
    if (queued = @_queued.find (job) -> job.tag == tag)?
      @_returnJob queued
    else
      @_rejectMiss()

  _promiseQueuedJob: (job) ->
    job.state = 'queued'
    @_queued.push job
    @emit 'queued', job
    @_returnJob job

  _runQueue: ->
    if @_queued.length > 0 and _.size(@_loading) < @options.maxLoading
      @_loadJob @_queued.pop()
    @

  # ==== HIT
  # Result cached in a file

  _promiseLoaded: (tag) ->
    pfs.createReadStream fn = @_tagToFn tag, 'data'
       .then (stream) =>
         @_updateLru tag
         stream: stream
         fn: fn
       .catch file_utils.isEnoent, @_rejectMiss

  # ==== MISS > ADD
  # Result not cached > load | queue

  _promiseMissing: (tag, cmd) ->
    job =
      tag: tag
      cmd: cmd
      now: new Date
      _proxy: new StreamProxy
    if _.size(@_loading) < @options.maxLoading
      @_promiseLoadingJob job
    else
      @_promiseQueuedJob job

  # ==== GET

  promise: (args...) ->
    @_promiseLoading args...
    .catch @isMiss, (error) =>
      @_promiseQueued args...
    .catch @isMiss, (error) =>
      @_promiseLoaded args...
    .catch @isMiss, (error) =>
      @_promiseMissing args...

module.exports = FileCache
