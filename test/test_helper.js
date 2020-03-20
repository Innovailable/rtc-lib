/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const comb = require('js-combinatorics');
const keys = require('object-keys');

exports.run_permutations = function(type, actions) {
  const desc_base = "should " + type + " after ";

  const run_order = order => done => Array.from(order).map((name) =>
    actions[name](done));

  const p = comb.permutation(keys(actions));

  return (() => {
    let order;
    const result = [];
    while ((order = p.next())) {
      const desc = desc_base + order.join(' -> ');
      result.push(it(desc, run_order(order)));
    }
    return result;
  })();
};
