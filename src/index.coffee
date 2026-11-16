# What a game's repo takes from the kit:
#   raccoongames build        the command (bin/raccoongames.js, release/build)
#   raccoongames-kit/release  what a release is, and the check of one
#   raccoongames-kit/play     the rules played by hand, for the game's tests
#   .github/workflows/release.yml  the release, for the game's repo to call
module.exports =
  release: require './release/release'
  play: require './play/play'
