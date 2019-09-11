_ = require 'lodash'

equality_marker = Symbol 'EqualityMarker'

_deinheritArray = (own, base) ->
  if _.isEqual own, base
    equality_marker
  else
    own

_deinheritObject = (own, base) ->
  result = {}

  for k, v of own
    if !_.has base, k
      result[k] = v
    else if (t = _deinherit v, base[k]) != equality_marker
      result[k] = t

  if _.isEmpty result then equality_marker else result

_deinherit = (own, base) ->
  if _.isArray(own) and _.isArray(base)
    _deinheritArray own, base
  else if _.isObject(own) and _.isObject(base)
    _deinheritObject own, base
  else if _.isEqual own, base
    equality_marker
  else
    own

diffArray = (a, b) ->
  _.zipWith a, b, diff

diffObject = (a, b) ->
  result = {}

  for k, v of a
    if _.has b, k
      result[k] = _diff v, b[k] unless _.isEqual v, b[k]
    else
      result[k] = a: v

  for k, v of b when !_.has a, k
    result[k] = b: v

  if _.isEmpty result then null else result

_diff = (a, b) ->
  if _.isArray(a) and _.isArray(b)
    diffArray a, b
  else if _.isObject(a) and _.isObject(b)
    diffObject a, b
  else
    a: a
    b: b

diff = (a, b) ->
  if _.isEqual a, b
    null
  else
    _diff a, b

module.exports =
  deinherit: (own, base, eqmark = null) ->
    if (t = _deinherit own, base) == equality_marker then eqmark else t

  diff: diff
  diffArray: diffArray
  diffObject: diffObject
