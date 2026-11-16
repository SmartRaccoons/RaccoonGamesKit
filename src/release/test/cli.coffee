{ assert } = require 'chai'
sinon = require 'sinon'
proxyquire = require 'proxyquire'


describe 'release cli', ->
  build = null
  run = null

  beforeEach ->
    build = sinon.stub().resolves {size: 8015, commit: 'abc123', icon: true}
    { run } = proxyquire '../cli', './build': {build}
    sinon.stub console, 'log'
    sinon.stub console, 'error'

  afterEach ->
    sinon.restore()

  it 'build: a line saying what was made', ->
    assert.equal await run(['build']), 0
    assert.equal build.callCount, 1
    assert.deepEqual console.log.args, [['dist/game.js 8015 bytes, commit abc123, icon']]

  it 'build: no commit, no icon', ->
    build.resolves {size: 10, commit: null, icon: false}
    await run ['build']
    assert.deepEqual console.log.args, [['dist/game.js 10 bytes, commit none, no icon']]

  it 'build failing: its line, and 1', ->
    build.rejects new Error 'src/icon.png is not a png'
    assert.equal await run(['build']), 1
    assert.deepEqual console.error.args, [['src/icon.png is not a png']]
    assert.equal console.log.callCount, 0

  it 'anything else: how it is used', ->
    for args in [[], ['release'], ['build', 'more']]
      assert.equal await run(args), 1
    assert.equal build.callCount, 0
    assert.deepEqual console.error.lastCall.args, ['usage: raccoongames build']
