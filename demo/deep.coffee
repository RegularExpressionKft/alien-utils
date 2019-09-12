deep = require '../deep'

own =
  a:
    aa: 'alma'
    ab: 'barac'
  b:
    ba: 'almafa'
    bb: 'barac'
  c: null
  d:
    da: 'alma'
    db: 'barac'

inherited =
  a:
    aa: 'alma'
    ab: 'barac'
  b:
    ba: 'alma'
    bb: 'barac'
  c:
    ca: 'alma'
    cb: 'barac'
  e:
    ea: 'alma'
    eb: 'barac'

console.log 'deinherit', deep.deinherit own, inherited
console.log 'diff', deep.diff own, inherited
