{ assert } = require 'chai'
fs = require 'fs'
os = require 'os'
path = require 'path'
{ check, contractValid, iconProblem, ICON_MAX } = require '../release'


PNG = Buffer.from [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0]

describe 'release', ->
  dir = null
  # a real folder each time: the links are real ones
  put = (name, content)-> fs.writeFileSync path.join(dir, name), content

  beforeEach ->
    dir = fs.mkdtempSync path.join os.tmpdir(), 'release-'
    put 'game.js', 'Game={}'
    put 'manifest.json', '{"contract": 1, "commit": "abc", "size": 7}'

  afterEach ->
    fs.rmSync dir, {recursive: true, force: true}


  it 'contractValid: a whole number, 1 or more', ->
    for value in [1, 2, 50]
      assert.isTrue contractValid(value), "#{value}"
    for value in [0, -1, 1.5, '1', null, undefined, NaN, [1]]
      assert.isFalse contractValid(value), "#{value}"


  describe 'iconProblem: why bytes cannot be an icon', ->
    it 'a png, not too big: none', ->
      assert.equal ICON_MAX, 256 * 1024
      assert.isNull iconProblem PNG
      assert.isNull iconProblem Buffer.concat [PNG, Buffer.alloc ICON_MAX - PNG.length]

    it 'not a png', ->
      for data in [Buffer.from('<svg></svg>'), Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0, 0]), Buffer.alloc(0), 'png', null]
        assert.equal iconProblem(data), 'is not a png'

    it 'too big', ->
      assert.equal iconProblem(Buffer.concat [PNG, Buffer.alloc ICON_MAX]), 'is over 256 kB'


  describe 'check: whether a folder is a release', ->
    it 'game.js and a manifest naming the contract', ->
      assert.deepEqual check(dir), {contract: 1, icon: false}

    it 'with its icon', ->
      put 'icon.png', PNG
      assert.deepEqual check(dir), {contract: 1, icon: true}

    it 'a file missing', ->
      fs.rmSync path.join dir, 'game.js'
      assert.throws (-> check dir), /^not a release: no game.js$/
      put 'game.js', 'Game={}'
      fs.rmSync path.join dir, 'manifest.json'
      assert.throws (-> check dir), /^not a release: no manifest.json$/

    it 'a folder that is not there', ->
      assert.throws (-> check path.join dir, 'none'), /^not a release: no game.js$/

    it 'a link is not a file: never followed', ->
      outside = path.join dir, 'outside.json'
      put 'outside.json', '{"contract": 1}'
      fs.rmSync path.join dir, 'manifest.json'
      fs.symlinkSync outside, path.join dir, 'manifest.json'
      assert.throws (-> check dir), /^not a release: no manifest.json$/
      fs.rmSync path.join dir, 'manifest.json'
      put 'manifest.json', '{"contract": 1}'
      fs.symlinkSync outside, path.join dir, 'icon.png'
      assert.throws (-> check dir), /^not a release: icon.png is not a file$/

    it 'a manifest that does not read, or names no contract', ->
      for text in ['', 'not json', 'null', '[]', '{}', '{"contract": "1"}', '{"contract": 0}', '{"contract": 1.5}']
        put 'manifest.json', text
        assert.throws (-> check dir), /^not a release: manifest.json names no contract$/, text

    it 'an icon that is too big, or not a png', ->
      put 'icon.png', Buffer.concat [PNG, Buffer.alloc ICON_MAX]
      assert.throws (-> check dir), /^not a release: icon.png is over 256 kB$/
      put 'icon.png', '<svg></svg>'
      assert.throws (-> check dir), /^not a release: icon.png is not a png$/
