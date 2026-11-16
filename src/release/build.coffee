# A game's folder into its release (./release.coffee says what that is):
# `raccoongames build`, run in the game's repo, by hand or by its github
# workflow. What it reads there:
#
#   src/index.coffee  the rules: what it exports as Game is the game
#   src/icon.png      the game's icon, if it has one; taken as it is
#   package.json      raccoongames.contract: the contract the rules are
#                     written for
#
# and what it leaves is dist/, made anew each time.
fs = require 'fs'
path = require 'path'
vm = require 'vm'
{ execFileSync } = require 'child_process'
esbuild = require 'esbuild'
CoffeeScript = require 'coffeescript'
{ check, contractValid, iconProblem } = require './release'


coffee =
  name: 'coffee'
  setup: (build)->
    build.onLoad {filter: /\.coffee$/}, (args)->
      contents: CoffeeScript.compile fs.readFileSync(args.path, 'utf8'), {bare: true, filename: args.path}
      loader: 'js'


# the contract the game is written for: its package.json says it
module.exports.contract = contract = (root)->
  value = try JSON.parse(fs.readFileSync path.join(root, 'package.json'), 'utf8').raccoongames?.contract
  if !contractValid value
    throw new Error 'package.json: raccoongames.contract has to be a whole number, 1 or more'
  value


# the commit being built: the one a github build names, or the folder's own
module.exports.commit = commit = (root)->
  if process.env.GITHUB_SHA
    return process.env.GITHUB_SHA
  try
    execFileSync('git', ['rev-parse', 'HEAD'], {cwd: root, stdio: ['ignore', 'pipe', 'ignore']}).toString().trim()
  catch
    null


# The file is run the way the platform runs it: alone, with no node around
# it (no require, no process, no timers). So a rule that leans on any of
# that fails here and not after the release.
module.exports.rules = rules = (source)->
  context = vm.createContext {}
  vm.runInContext source, context, {timeout: 1000}
  missing = ['setup', 'start', 'end'].filter (name)->
    !vm.runInContext "typeof Game === 'object' && typeof Game.#{name} === 'function'", context
  if missing.length > 0
    throw new Error "game.js: Game has no #{missing.join ', '}"


# The icon goes along as it is, when there is one. The platform refuses a
# whole release over an icon it does not take, so that is said here.
icon = (root, out)->
  from = path.join root, 'src/icon.png'
  if !fs.existsSync from
    return false
  data = fs.readFileSync from
  problem = iconProblem data
  if problem
    throw new Error "src/icon.png #{problem}"
  fs.writeFileSync path.join(out, 'icon.png'), data
  true


# root: the game's folder. Answers {out, contract, commit, size, icon};
# throws, in a line, when the game cannot be released.
module.exports.build = ({root = process.cwd()} = {})->
  out = path.join root, 'dist'
  # asked first: a game that names no contract is not built at all
  manifest = {contract: contract(root), commit: commit(root), size: 0}
  fs.rmSync out, {recursive: true, force: true}
  file = path.join out, 'game.js'
  await esbuild.build
    entryPoints: [path.join root, 'src/index.coffee']
    outfile: file
    bundle: true
    minify: true
    format: 'iife'
    globalName: 'Arena'
    footer: {js: 'globalThis.Game=Arena.Game;'}
    resolveExtensions: ['.coffee', '.js']
    plugins: [coffee]
    logLevel: 'warning'
  source = fs.readFileSync file, 'utf8'
  rules source
  manifest.size = Buffer.byteLength source
  fs.writeFileSync path.join(out, 'manifest.json'), "#{JSON.stringify manifest, null, 2}\n"
  icon root, out
  # what was made is asked the platform's own question
  Object.assign {out}, manifest, {icon: check(out).icon}
