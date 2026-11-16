# The kit's command, run in a game's folder: raccoongames <command>
# (bin/raccoongames.js).
#   build   the game into its release, dist/ (./build.coffee)
{ build } = require './build'


# Answers the exit code: 0, or 1 with a line saying why.
module.exports.run = (args = process.argv.slice 2)->
  if args.length isnt 1 or args[0] isnt 'build'
    console.error 'usage: raccoongames build'
    return 1
  try
    {size, commit, icon} = await build()
    console.log "dist/game.js #{size} bytes, commit #{commit or 'none'}, #{if icon then 'icon' else 'no icon'}"
    0
  catch e
    console.error e.message
    1
