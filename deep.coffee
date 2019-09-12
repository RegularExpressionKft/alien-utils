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

diffArray = (left, right) ->
  _.zipWith left, right, diff

diffObject = (left, right) ->
  result = {}

  for k, v of left
    if _.has right, k
      result[k] = _diff v, right[k] unless _.isEqual v, right[k]
    else
      result[k] = left: v

  result[k] = right: v for k, v of right when !_.has left, k

  if _.isEmpty result then null else result

_diff = (left, right) ->
  if _.isArray(left) and _.isArray(right)
    diffArray left, right
  else if _.isObject(left) and _.isObject(right)
    diffObject left, right
  else
    left: left
    right: right

diff = (left, right) ->
  if _.isEqual left, right then null else _diff left, right

module.exports =
  deinherit: (own, base, eqmark = null) ->
    if (t = _deinherit own, base) == equality_marker then eqmark else t

  diff: diff
  diffArray: diffArray
  diffObject: diffObject
