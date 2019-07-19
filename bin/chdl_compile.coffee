#!/usr/bin/env coffee

fs = require 'fs'
path = require 'path'
_ = require 'lodash'
log = require 'fancy-log'
{printBuffer}=require 'chdl_utils'
{transToVerilog,setPaths}=require 'chdl_transpiler_engine'
{configBase}=require 'chdl_base'
mkdirp= require 'mkdirp'

args = require('minimist')(process.argv.slice(2))

if args.help?
  console.log "Usage:"
  console.log "  chdl_compile.coffee [--autoClock] chdl_file [--output=out_dir]"
  process.exit()

cfg={
  autoClock:false
}
if args.autoClock
  cfg.autoClock=true
configBase(cfg)

programParam= args.param ? ''

processFile= (fileName,outDir) ->
  setPaths([path.dirname(path.resolve(fileName)),process.env.NODE_PATH.split(/:/)...,module.paths...])
  fs.readFile fileName, 'utf-8', (error, text) ->
    return if error
    javascript=transToVerilog(text,false,programParam)
    printBuffer.flush()
    for i,index in printBuffer.getBin()
      code= i.list.join("\n")
      do ->
        fname= do ->
          if outDir?
            outDir+'/'+i.name
          else
            i.name
        fs.writeFile fname+'.v', code, (err) =>
          throw err if err
          log "generate code",fname+".v"

fileName = args._[0]
outDir= args.output ? './'
log 'Generate code to directory "'+outDir+'"' if outDir?
if not fs.existsSync(outDir)
  mkdirp.sync(outDir)

unless fileName
  log 'No file specified'
  process.exit()

processFile(fileName,outDir.replace(/\/$/,''))

