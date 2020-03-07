#!/usr/bin/env coffee

fs = require 'fs'
path = require 'path'
_ = require 'lodash'
log = require 'fancy-log'
{simBuffer,printBuffer}=require 'chdl_utils'
{buildCode,setPaths}=require 'chdl_transpiler_engine'
{configBase,resetBase}=require 'chdl_base'
global  = require('chdl_global')
mkdirp= require 'mkdirp'
chokidar = require('chokidar')
program = require('commander')
spawn = require('child_process').spawn


banner= (topFile)->
    console.log '|          ╔═╗┌─┐┌─┐┌─┐┌─┐┌─┐  ┬ ┬┌┬┐┬'
    console.log '|          ║  │ │├┤ ├┤ ├┤ ├┤   ├─┤ │││'
    console.log '|          ╚═╝└─┘└  └  └─┘└─┘  ┴ ┴─┴┘┴─┘'
    log "Top file #{topFile}"

program
  .version('0.0.1')
  .name('chdl_compile.coffee')
  .usage('[options] source_file')
  .option('-o, --output <dir name>')
  .option('-w, --watch')
  .option('-p, --param_file <file name>')
  .option('-a, --autoClock')
  .option('-t, --tree')
  .option('-i, --info')
  .option('-n, --new <module name>')
  .option('--flist <file list name>')
  .option('--fsdb')
  .option('--no_always_comb')
  .option('--ncsim')
  .option('--vcs')
  .option('--iverilog')
  .option('--prefix <prefix to auto signal>')
  .option('--buildsim')
  .option('--nolineno')
  .option('--force')
  .option('--debug')
  .parse(process.argv)

debug = program.debug ? false

if program.new?
  moduleName = program.new
  code = """
class #{moduleName} extends Module
  constructor: ->
    super()

    #CellMap(name: new cell())

    Port(
    )

    Wire(
    )

    Reg(
    )

    Channel(
    )

  build: ->

module.exports=#{moduleName}
"""
  fs.writeFileSync("./#{moduleName}.chdl",code,'utf8')
  process.exit()

cfg={
  autoClock: program.autoClock ? false
  tree: program.tree ? false
  info: program.info ? false
  noLineno: program.no_lineno ? false
  noAlwaysComb: program.no_always_comb ? false
  waveFormat: do ->
    if program.fsdb
      'fsdb'
    else
      'vcd'
}

if program.prefix?
  global.setPrefix(program.prefix)

if program.force?
  global.setForce()

if program.iverilog
  cfg.noAlwaysComb = true

if program.buildsim
  global.setSim()

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
      buildCode(path.resolve(fileName),text,debug,programParam)
      flist=[]
      for i,index in simBuffer.getBin()
        fname= do ->
          if outDir?
            outDir+'/'+i.name
          else
            i.name
        fs.writeFileSync(fname+'.sim.js', i.list.join("\n"),'utf8')
      for i,index in printBuffer.getBin()
        code= i.list.join("\n")
        fname= do ->
          if outDir?
            outDir+'/'+i.name
          else
            i.name
        flist.push(fname+'.sv')
        fs.writeFileSync(fname+'.sv', code,'utf8')
        log "generate code",fname+".sv"

      if program.flist
        fs.writeFileSync(program.flist,flist.join("\n"),'utf8')
      if program.ncsim
        args=['-64bit','-access +rwc',flist...]
        log "[ncverilog #{args.join(' ')}]"
        spawn('ncverilog',args,{stdio:['pipe',1,2]})
      if program.vcs
        args=['-full64','-R','-debug_access+all','-sverilog',flist...]
        log "[vcs #{args.join(' ')}]"
        spawn('vcs',args,{stdio:['pipe',1,2]})
      if program.iverilog
        args=['-o',outDir+'/sim_ivl','-g2012',flist...]
        log "[iverilog #{args.join(' ')}]"
        handler=spawn('iverilog',args,{stdio:['pipe',1,2]})
        handler.on('exit',->
          handler=spawn(outDir+'/sim_ivl',{stdio:['pipe',1,2]})
        )

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
if not fs.existsSync(outDir)
  mkdirp.sync(outDir)

#if not fs.existsSync('./build')
#  mkdirp.sync('./build')

unless fileName
  log 'No file specified'
  process.exit()

banner(fileName)
log 'Generate code to directory "'+outDir+'"' if outDir?
processFile(fileName,outDir.replace(/\/$/,''))

if program.watch
  watch=chokidar.watch(fileName)
  watch.on('change',(path)->
    resetBase()
    printBuffer.clearBin()
    simBuffer.clearBin()
    banner(fileName)
    processFile(fileName,outDir.replace(/\/$/,''))
  )
