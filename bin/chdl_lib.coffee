#!/usr/bin/env coffee

banner= ->
    console.log '|          ╔═╗┌─┐┌─┐┌─┐┌─┐┌─┐  ┬ ┬┌┬┐┬'
    console.log '|          ║  │ │├┤ ├┤ ├┤ ├┤   ├─┤ │││'
    console.log '|          ╚═╝└─┘└  └  └─┘└─┘  ┴ ┴─┴┘┴─┘'

fs = require 'fs'
path = require 'path'
_ = require 'lodash'
log = require 'fancy-log'
{printBuffer}=require 'chdl_utils'
{buildLib,setPaths}=require 'chdl_transpiler_engine'
{configBase,resetBase}=require 'chdl_base'
mkdirp= require 'mkdirp'
chokidar = require('chokidar')
program = require('commander')

program
  .version('0.0.1')
  .name('chdl_lib.coffee')
  .usage('[options] source_file')
  .option('--debug')
  .parse(process.argv)

debug = program.debug ? false

configBase({lib:true})

processFile= (fileName) ->
  setPaths([path.dirname(path.resolve(fileName)),process.env.NODE_PATH.split(/:/)...,module.paths...])
  fs.readFile fileName, 'utf-8', (error, text) ->
    if error
      log.error error
      return
    try
      buildLib(path.resolve(fileName),text,debug)
      log "================================="
      log " Build library #{fileName}"
      log "================================="
    catch e
      log.error e
      if (e instanceof TypeError) or (e instanceof ReferenceError)
        lines=e.stack.toString().split(/\s+at\s+/)
        if lines.length>1
          m=lines[1].match(/\((.*)\)/)
          if m?
            [jsfile,lineno]=m[1].split(/:/)
            log.error 'Error at "'+fs.readFileSync(jsfile,'utf8').split(/\n/)[Number(lineno-1)].trim()+'"'

if program.args.length==0
  log 'No file specified'
  process.exit()

for fileName in program.args
  processFile(fileName)

