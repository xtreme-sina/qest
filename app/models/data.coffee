
EventEmitter = require('events').EventEmitter

globalEventEmitter = new EventEmitter()
events = null

getEventEmitter = (key) ->
  events[key] ||= new EventEmitter()

KEYS_SET_NAME = 'keys'

module.exports = (app) ->
  
  class Data

    constructor: (@key, @value) ->
      @value ||= null
    
    getKey: () -> @key

    getValue: () -> @value

    setValue: (val) -> @value = val

    on: (event, callback) ->
      getEventEmitter(@key).on(event, callback)
      @

    removeListener: (event, callback) ->
      getEventEmitter(@key).removeListener(event, callback)
      @

    save: (callback) ->
      getEventEmitter(@key).emit('change', @)

      app.redis.client.sismember KEYS_SET_NAME, @key, (err, result) =>
        globalEventEmitter.emit("newData", @) if result == 0
        app.redis.client.sadd(KEYS_SET_NAME, @key)

      app.redis.client.set @key, @value, (=> callback(@) if callback?)

      @

  Data.find = (pattern, callback) ->

    foundRecord = (key) ->
      app.redis.client.get key, (err, value) ->
        error = "Record not found" unless value?
        callback(new Data(key, value), error) if callback?

    if pattern.constructor != RegExp
      foundRecord(pattern)
    else
      app.redis.client.smembers KEYS_SET_NAME, (err, topics) ->
        for topic in topics
          foundRecord(topic) if pattern.test(topic)

    Data

  Data.findOrCreate = ->
    args = Array.prototype.slice.call arguments

    key = args.shift() # first arg shifted out

    arg = args.shift() # second arg popped out
    if typeof arg == 'function'
      # if the second arg is a function,
      # then there is no third arg
      callback = arg 
    else
      # if the second arg is not a function
      # then it's the value, and the third is
      # the callback
      value = arg 
      callback = args.shift()

    # FIXME this is not atomic, is it a problem?
    app.redis.client.get key, (err, oldValue) ->
      data = new Data(key, oldValue)
      if value?
        data.setValue(value)
        data.save(callback)
      else
        callback(data) if callback?

    Data

  Data.reset = ->
    events = {}
    globalEventEmitter.removeAllListeners()

  Data.reset()

  Data.on = (event, callback) ->
    globalEventEmitter.on(event, callback)
    @

  Data.removeListener = (event, callback) ->
    globalEventEmitter.removeListener(event, callback)
    @

  Data
