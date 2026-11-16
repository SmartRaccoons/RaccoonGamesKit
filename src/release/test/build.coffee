{ assert } = require 'chai'
sinon = require 'sinon'
proxyquire = require 'proxyquire'
fs = require 'fs'
os = require 'os'
path = require 'path'
vm = require 'vm'
{ build, contract, commit, rules } = require '../build'
{ check } = require '../release'


PNG = Buffer.from [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0]

describe 'release build', ->
  root = null
  sha = null
  # a game's folder, a real one: the build is run whole
  put = (name, content)->
    fs.mkdirSync path.dirname(path.join root, name), {recursive: true}
    fs.writeFileSync path.join(root, name), content

  beforeEach ->
    root = fs.mkdtempSync path.join os.tmpdir(), 'game-'
    put 'package.json', '{"name": "game", "raccoongames": {"contract": 2}}'
    put 'src/index.coffee', """
      { deal } = require './cards'
      module.exports.Game =
        setup: ({game})-> game.set = true
        start: ({game})-> game.cards = deal()
        end: ->
      module.exports.locale = {en: {name: 'Game'}}
    """
    put 'src/cards.coffee', 'module.exports.deal = -> [1, 2, 3]'
    sha = process.env.GITHUB_SHA
    process.env.GITHUB_SHA = 'abc123'

  afterEach ->
    if sha? then process.env.GITHUB_SHA = sha else delete process.env.GITHUB_SHA
    fs.rmSync root, {recursive: true, force: true}


  describe 'contract: what the game\'s package.json says', ->
    it 'the number', ->
      assert.equal contract(root), 2

    it 'none, not a whole number, or no package.json', ->
      for text in ['{}', '{"raccoongames": {}}', '{"raccoongames": {"contract": "1"}}', '{"raccoongames": {"contract": 0}}', 'not json']
        put 'package.json', text
        assert.throws (-> contract root), /^package.json: raccoongames.contract has to be a whole number, 1 or more$/, text
      fs.rmSync path.join root, 'package.json'
      assert.throws (-> contract root), /raccoongames.contract/


  describe 'commit: what is being built', ->
    it 'the one a github build names', ->
      assert.equal commit(root), 'abc123'

    it 'a folder that is no repo: none', ->
      delete process.env.GITHUB_SHA
      { commit: commit_none } = proxyquire '../build',
        child_process: {execFileSync: -> throw new Error 'not a git repository'}
      assert.isNull commit_none root

    it 'the folder\'s own', ->
      delete process.env.GITHUB_SHA
      execFileSync = sinon.spy -> Buffer.from 'def456\n'
      { commit: commit_own } = proxyquire '../build', child_process: {execFileSync}
      assert.equal commit_own(root), 'def456'
      assert.deepEqual execFileSync.lastCall.args.slice(0, 2), ['git', ['rev-parse', 'HEAD']]
      assert.equal execFileSync.lastCall.args[2].cwd, root


  describe 'rules: game.js run alone, as the platform runs it', ->
    it 'a Game with setup, start and end', ->
      assert.doesNotThrow -> rules 'globalThis.Game={setup(){},start(){},end(){}}'

    it 'what is missing is named', ->
      assert.throws (-> rules 'globalThis.Game={setup(){}}'), /^game.js: Game has no start, end$/
      assert.throws (-> rules ''), /^game.js: Game has no setup, start, end$/

    it 'nothing of node is there to lean on', ->
      for source in ['require("fs")', 'process.env.X', 'setTimeout(function(){}, 1)']
        assert.throws (-> rules source), /is not defined/, source


  describe 'build: the folder into dist/', ->
    it 'game.js, alone and whole, and the manifest', ->
      result = await build {root}
      out = path.join root, 'dist'
      source = fs.readFileSync path.join(out, 'game.js'), 'utf8'
      assert.deepEqual result, {out, contract: 2, commit: 'abc123', size: Buffer.byteLength(source), icon: false}
      assert.deepEqual JSON.parse(fs.readFileSync path.join(out, 'manifest.json'), 'utf8'), {contract: 2, commit: 'abc123', size: result.size}
      assert.deepEqual fs.readdirSync(out).sort(), ['game.js', 'manifest.json']
      # run with nothing around it, the rules play, the other file with them
      context = vm.createContext {}
      vm.runInContext source, context
      assert.deepEqual vm.runInContext('var g = {}; Game.setup({game: g}); Game.start({game: g}); JSON.stringify(g)', context), '{"set":true,"cards":[1,2,3]}'
      assert.equal vm.runInContext('Arena.locale.en.name', context), 'Game'
      # and it is what the platform takes
      assert.deepEqual check(out), {contract: 2, icon: false}

    it 'with the icon, as it is', ->
      put 'src/icon.png', PNG
      result = await build {root}
      assert.isTrue result.icon
      assert.isTrue fs.readFileSync(path.join root, 'dist/icon.png').equals PNG

    it 'made anew: nothing of the last build stays', ->
      put 'dist/old.js', 'old'
      put 'dist/icon.png', PNG
      await build {root}
      assert.deepEqual fs.readdirSync(path.join root, 'dist').sort(), ['game.js', 'manifest.json']

    it 'an icon the platform does not take: no release', ->
      put 'src/icon.png', '<svg></svg>'
      try
        await build {root}
        assert.fail 'should throw'
      catch e
        assert.equal e.message, 'src/icon.png is not a png'

    it 'no contract: nothing is built', ->
      put 'package.json', '{}'
      put 'dist/old.js', 'old'
      try
        await build {root}
        assert.fail 'should throw'
      catch e
        assert.match e.message, /raccoongames.contract/
      assert.deepEqual fs.readdirSync(path.join root, 'dist'), ['old.js']

    it 'rules that are not a game', ->
      put 'src/index.coffee', 'module.exports.Game = {setup: ->}'
      try
        await build {root}
        assert.fail 'should throw'
      catch e
        assert.equal e.message, 'game.js: Game has no start, end'

    it 'rules that lean on node', ->
      put 'src/index.coffee', 'module.exports.Game = {setup: (-> process.env.X), start: (->), end: ->}\nprocess.title'
      try
        await build {root}
        assert.fail 'should throw'
      catch e
        assert.match e.message, /process is not defined/
