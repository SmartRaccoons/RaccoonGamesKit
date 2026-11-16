# A game's rules played the way the platform plays them, for the game's own
# tests: every call gets the game as JSON and hands JSON back, so nothing
# but data lives between two calls, and a delay is followed by its name. A
# rule that keeps something outside the game, or leaves a function in it,
# fails here.
#
#   { call, settle, move } = require('raccoongames-kit/play') Game
#   game = call {users: [{}, {}, {}]}, 'setup', {options: {...}}
#   game = settle call game, 'start'
#   game = move game, ({command, params})-> params[0]
assert = require 'assert'


copy = (value)-> JSON.parse JSON.stringify value

module.exports = (Game)->
  # one of the game's functions, by its path ('start', 'command.card.fn',
  # 'step.trick'), on a copy of the game; answers the game it left
  call = (game, path, params = {})->
    fn = path.split('.').reduce ((o, k)-> o?[k]), Game
    assert.equal typeof fn, 'function', "Game.#{path} is not a function"
    p = copy Object.assign {}, params, {game}
    fn p
    copy p.game

  # what the last call left to be run later, game.delay = [path, seconds,
  # params]: run now, and again while there is more
  settle = (game)->
    for _ in [0...1000]
      if !game.delay
        return game
      [path, seconds, params] = game.delay
      assert.equal typeof path, 'string', 'game.delay[0] has to be the name of a function'
      assert.equal typeof seconds, 'number', 'game.delay[1] has to be seconds'
      delete game.delay
      game = call game, path, params
    assert.fail 'game.delay never ends'

  # The first seat that is asked makes its move. A question is a list of
  # [command, params]; `choose` gets {i, command, params, ask} for the
  # first of them and answers what to play. Then the delays are followed.
  move = (game, choose)->
    i = game.users.findIndex (u)-> u and u.ask
    assert.notEqual i, -1, 'no seat is asked'
    ask = game.users[i].ask
    assert.ok Array.isArray(ask) and Array.isArray(ask[0]), 'ask has to be a list of [command, params]'
    [command, params] = ask[0]
    assert.equal typeof command, 'string', 'a question starts with the name of a command'
    param = choose {i, command, params, ask}
    game.users[i].ask = null
    settle call game, "command.#{command}.fn", {i, params, param}

  {call, settle, move}
