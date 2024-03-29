#!/usr/bin/env coffee

banner= ->
    console.log '|          ╔═╗┌─┐┌─┐┌─┐┌─┐┌─┐  ┬ ┬┌┬┐┬'
    console.log '|          ║  │ │├┤ ├┤ ├┤ ├┤   ├─┤ │││'
    console.log '|          ╚═╝└─┘└  └  └─┘└─┘  ┴ ┴─┴┘┴─┘'

fs = require 'fs'
path = require 'path'
_ = require 'lodash'
log = require 'fancy-log'
{buildLib,setPaths}=require 'chdl_transpiler_engine'
{configBase,resetBase}=require 'chdl_base'
global  = require('chdl_global')
mkdirp= require 'mkdirp'
chokidar = require('chokidar')
program = require('commander')

program
  .version('0.0.1')
  .name('chdl_lib.coffee')
  .usage('[options] source_file')
  .option('--force')
  .option('--debug')
  .parse(process.argv)

debug = program.debug ? false

if program.force?
  global.setForce()

configBase({lib:true})

processFile= (fileName) ->
  setPaths([path.dirname(path.resolve(fileName)),process.env.NODE_PATH.split(/:/)...,module.paths...])
  text = fs.readFileSync(fileName, 'utf-8')
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

