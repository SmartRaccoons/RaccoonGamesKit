#!/usr/bin/env node
// raccoongames <command>: src/release/cli.coffee
require('coffeescript/register');
require('../src/release/cli.coffee').run().then((code) => process.exit(code));
