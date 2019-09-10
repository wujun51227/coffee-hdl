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
{buildCode,setPaths}=require 'chdl_transpiler_engine'
{configBase,resetBase}=require 'chdl_base'
mkdirp= require 'mkdirp'
chokidar = require('chokidar')
program = require('commander')

program
  .version('0.0.1')
  .name('chdl_compile.coffee')
  .usage('[options] source_file')
  .option('-o, --output <dir name>')
  .option('-w, --watch')
  .option('-p, --param_file <file name>')
  .option('-a, --autoClock')
  .option('-t, --tree')
  .option('--debug')
  .parse(process.argv)

debug = program.debug ? false

cfg={
  autoClock: program.autoClock ? false
  tree: program.tree ? false
}

configBase(cfg)

programParam=null

if fs.existsSync("./chdl_config.json")
  programParam= require path.resolve("./chdl_config.json")

if program.param_file?
  if fs.existsSync(path.resolve(program.param_file))
    programParam= require path.resolve(program.param_file)
  else
    log "Can not find file #{program.param_file}"
    
processFile= (fileName,outDir) ->
  setPaths([path.dirname(path.resolve(fileName)),process.env.NODE_PATH.split(/:/)...,module.paths...])
  fs.readFile fileName, 'utf-8', (error, text) ->
    if error
      log.error error
      return
    try
      buildCode(fileName,text,debug,programParam)
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
    catch e
      log.error e
      if (e instanceof TypeError) or (e instanceof ReferenceError)
        lines=e.stack.toString().split(/\s+at\s+/)
        if lines.length>1
          m=lines[1].match(/\((.*)\)/)
          if m?
            [jsfile,lineno]=m[1].split(/:/)
            log.error 'Error at "'+fs.readFileSync(jsfile,'utf8').split(/\n/)[Number(lineno-1)].trim()+'"'


fileName = program.args[0]
outDir= program.output ? './'
log 'Generate code to directory "'+outDir+'"' if outDir?
if not fs.existsSync(outDir)
  mkdirp.sync(outDir)

#if not fs.existsSync('./build')
#  mkdirp.sync('./build')

unless fileName
  log 'No file specified'
  process.exit()

banner()
processFile(fileName,outDir.replace(/\/$/,''))

if program.watch
  watch=chokidar.watch(fileName)
  watch.on('change',(path)->
    resetBase()
    printBuffer.clearBin()
    banner()
    processFile(fileName,outDir.replace(/\/$/,''))
  )
