assert = require 'assert'
_ = require 'lodash'

all = (args...) ->
  things = {}
  for thing in _.flatten args
    assert _.isString(thing), 'thing is string'
    assert.fail "unique thing (#{thing})" if things[thing]?
    things[thing] = false
  assert !_.isEmpty(things), 'have something'

  provider = (thing) ->
    assert _.isString(thing), 'thing is string'
    assert.fail "thing (#{thing}) exists" unless things[thing]?

    if things[thing]
      if provider.strict
        assert.fail "thing (#{thing}) is provided only once"
      provider.onRepeat? thing
      provider.done
    else
      things[thing] = true
      provider.onProvide? thing

      if _.every things
        provider.done = true
        provider.onDone?()
        true
      else
        null
  provider.done = false

  provider

module.exports = all
