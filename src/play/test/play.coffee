{ assert } = require 'chai'
play = require '../play'


# a game of one question: each seat in turn says a number, three in all
Game =
  setup: ({game, options})->
    game.said = []
    game.most = options.most
  start: ({game})->
    game.users[0].ask = [['say', [1, 2, 3]]]
  command:
    say:
      fn: ({game, i, param})->
        game.said.push [i, param]
        game.delay = ['step.next', 1, {i}]
  step:
    next: ({game, i})->
      if game.said.length >= game.most
        game.delay = ['step.over', 0]
        return
      game.users[(i + 1) % game.users.length].ask = [['say', [1, 2, 3]], ['pass']]
    over: ({game})->
      game.end = true


describe 'play', ->
  call = null
  settle = null
  move = null

  beforeEach ->
    {call, settle, move} = play Game

  describe 'call: one of the game\'s functions, on a copy', ->
    it 'the game it left', ->
      before = {users: [{}, {}]}
      game = call before, 'setup', {options: {most: 3}}
      assert.deepEqual game, {users: [{}, {}], said: [], most: 3}
      # the game handed in is not the one that was changed
      assert.deepEqual before, {users: [{}, {}]}

    it 'by its path', ->
      game = call {users: [{}, {}], said: []}, 'command.say.fn', {i: 1, param: 2}
      assert.deepEqual game.said, [[1, 2]]
      assert.deepEqual game.delay, ['step.next', 1, {i: 1}]

    it 'nothing but data comes through', ->
      game = play({start: ({game})-> game.fn = (->); game.when = new Date 0}).call {}, 'start'
      assert.deepEqual game, {when: '1970-01-01T00:00:00.000Z'}

    it 'no such function', ->
      assert.throws (-> call {}, 'command.none.fn'), /Game.command.none.fn is not a function/
      assert.throws (-> call {}, 'step'), /Game.step is not a function/

  describe 'settle: the delays followed, by name', ->
    it 'one after another, till there is none', ->
      game = settle {users: [{}, {}], said: [[0, 1]], most: 1, delay: ['step.next', 1, {i: 0}]}
      assert.equal game.end, true
      assert.equal game.delay, undefined

    it 'no delay: the game as it is', ->
      assert.deepEqual settle({users: []}), {users: []}

    it 'a delay that is a function, or has no seconds', ->
      assert.throws (-> settle {delay: [(->), 1]}), /name of a function/
      assert.throws (-> settle {delay: ['step.over']}), /seconds/

    it 'a delay that never ends', ->
      loop_ = play {step: again: ({game})-> game.delay = ['step.again', 0]}
      assert.throws (-> loop_.settle {delay: ['step.again', 0]}), /never ends/

  describe 'move: the seat that is asked plays', ->
    game = null
    beforeEach ->
      game = settle call call({users: [{}, {}]}, 'setup', {options: {most: 2}}), 'start'

    it 'the first question, answered by choose, and the delays after it', ->
      seen = null
      game = move game, (question)->
        seen = question
        question.params[2]
      assert.deepEqual seen, {i: 0, command: 'say', params: [1, 2, 3], ask: [['say', [1, 2, 3]]]}
      assert.deepEqual game.said, [[0, 3]]
      assert.equal game.users[0].ask, null
      assert.deepEqual game.users[1].ask, [['say', [1, 2, 3]], ['pass']]

    it 'a whole game', ->
      game = move game, -> 1
      game = move game, ({ask})->
        assert.equal ask.length, 2
        2
      assert.deepEqual game.said, [[0, 1], [1, 2]]
      assert.equal game.end, true

    it 'nobody is asked', ->
      assert.throws (-> move {users: [{}, null]}, -> 1), /no seat is asked/

    it 'a question in another shape', ->
      assert.throws (-> move {users: [{ask: ['say', [1]]}]}, -> 1), /list of \[command, params\]/
      assert.throws (-> move {users: [{ask: true}]}, -> 1), /list of \[command, params\]/
