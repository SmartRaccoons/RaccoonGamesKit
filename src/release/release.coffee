# What a release is: the folder a game's build makes (./build.coffee) and
# the platform reads (the server's arena sync). Written once, here, so the
# two cannot come to disagree: a build that passes is a release the
# platform takes.
#
#   game.js        the rules as one file, with nothing to load besides
#   manifest.json  {contract, commit, size}: the contract the rules are
#                  written for, the commit they were built from, game.js's
#                  size
#   icon.png       the game's icon, when it has one
#
# Nothing here but fs and path: the platform asks this of folders that are
# not its own, and runs nothing of theirs.
fs = require 'fs'
path = require 'path'


# an icon is a png, by its first bytes, and no bigger than this
module.exports.ICON_MAX = ICON_MAX = 256 * 1024
PNG = Buffer.from [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]


# Which version of the platform's rules interface a game is written for: a
# whole number, 1 or more. A game says it in its package.json, under
# raccoongames.contract; a release, in its manifest.
module.exports.contractValid = contractValid = (value)->
  Number.isInteger(value) and value >= 1


# Why these bytes cannot be an icon, in a few words, or null when they can.
module.exports.iconProblem = iconProblem = (data)->
  if !Buffer.isBuffer(data) or !data.subarray(0, PNG.length).equals PNG
    return 'is not a png'
  if data.length > ICON_MAX
    return "is over #{ICON_MAX / 1024} kB"
  null


# Whether a folder is a release. Answers {contract, icon}, icon being
# whether it brings one; throws, in a line, when it is not. Every file has
# to be a plain one: a link is not followed, so a release cannot point its
# reader at a file of the reader's own machine.
module.exports.check = (dir)->
  stat = (name)->
    try fs.lstatSync path.join dir, name
  for name in ['game.js', 'manifest.json']
    if !stat(name)?.isFile()
      throw new Error "not a release: no #{name}"
  manifest = try JSON.parse fs.readFileSync path.join(dir, 'manifest.json'), 'utf8'
  if !contractValid manifest?.contract
    throw new Error 'not a release: manifest.json names no contract'
  icon = stat 'icon.png'
  if icon
    if !icon.isFile()
      throw new Error 'not a release: icon.png is not a file'
    # the size first: a file that is too big is not even read
    if icon.size > ICON_MAX
      throw new Error "not a release: icon.png is over #{ICON_MAX / 1024} kB"
    problem = iconProblem fs.readFileSync path.join dir, 'icon.png'
    if problem
      throw new Error "not a release: icon.png #{problem}"
  {contract: manifest.contract, icon: !!icon}
