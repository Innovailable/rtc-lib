comb = require('js-combinatorics')
keys = require('object-keys')

exports.run_permutations = (type, actions) ->
  desc_base = "should " + type + " after "

  run_order = (order) -> (done) ->
    for name in order
      actions[name](done)

  p = comb.permutation(keys(actions))

  while order = p.next()
    desc = desc_base + order.join(' -> ')
    it(desc, run_order(order))
