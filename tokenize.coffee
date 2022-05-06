no_more_matches =
  type: 'no_more_matches'

createIterators = (string, lexicon) ->
  iterators = {}
  for name, regexp of lexicon
    iterators[name] = string.matchAll regexp
  iterators

updateNextMatches = (next_matches, iterators, pos) ->
  for name, iterator of iterators when !(next = next_matches[name])? or
                                       (next.index? and next.index < pos)
    next_matches[name] =
      if iterator?
        next = null
        while iterator? and !next?
          y = iterator.next()
          next = y.value if y.value?.index? and y.value.index >= pos
          iterators[name] = iterator = null if y.done
        next ? no_more_matches
      else
        no_more_matches

  next_matches

getNextMatch = (next_matches) ->
  best_match = best_name = null

  for name, match of next_matches when match?.index?
    # Tie braking:
    #   1. zero width matches in lexicon order,
    #   2. the first (in lexicon order) longest non-zero-width match
    # lexicon order == next_matches order
    if !best_match? or (match.index < best_match.index) or
       ( match.index == best_match.index and
         best_match[0].length > 0 and
         ( match[0].length > best_match[0].length or
           match[0].length == 0 ) )
      best_match = match
      best_name = name

  best_name

createToken = (name, match) ->
  capture = match.slice()
  capture.groups = match.groups if match.groups?

  type: 'token'
  name: name
  text: capture[0]
  begin: match.index
  end: match.index + match[0].length
  capture: capture

tokenize = (string, lexicon) ->
  ret = []

  pos = 0
  iterators = createIterators string, lexicon
  next_matches = updateNextMatches {}, iterators, pos

  # minBy doesn't work with objects
  # while (token = _.minBy cache, 'begin')?
  while (name = getNextMatch next_matches)?
    match = next_matches[name]
    next_matches[name] = null

    if pos < match.index
      ret.push
        type: 'text'
        text: string.slice pos, match.index
        begin: pos
        end: match.index

    ret.push createToken name, match

    pos = match.index + match[0].length
    updateNextMatches next_matches, iterators, pos

  if pos < string.length
    ret.push
      type: 'text'
      text: if pos > 0 then string.slice pos else string
      begin: pos
      end: string.length

  ret

module.exports = tokenize
