#!/usr/bin/env coffee

fs = require 'fs'
path = require 'path'
_ = require 'lodash'
log = require 'fancy-log'
colors = require 'colors'
{simBuffer,printBuffer}=require 'chdl_utils'
{headOver,buildCode,setPaths}=require 'chdl_transpiler_engine'
{configBase,resetBase}=require 'chdl_base'
global  = require('chdl_global')
mkdirp= require 'mkdirp'
chokidar = require('chokidar')
program = require('commander')
spawn = require('child_process').spawn


banner= (topFile)->
    console.log '          ╔═╗┌─┐┌─┐┌─┐┌─┐┌─┐  ┬ ┬┌┬┐┬           '.brightBlue
    console.log '          ║  │ │├┤ ├┤ ├┤ ├┤   ├─┤ │││           '.brightBlue
    console.log '          ╚═╝└─┘└  └  └─┘└─┘  ┴ ┴─┴┘┴─┘         '.brightBlue
    log "Top file #{topFile}".magenta

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
  .option('--nowave')
  .option('--no_always_comb')
  .option('--ncsim')
  .option('--vcs')
  .option('--iverilog')
  .option('--prefix <prefix to auto signal>')
  .option('--buildsim')
  .option('--nolineno')
  .option('--release')
  .option('--force')
  .option('--lint')
  .option('--obfuscate')
  .option('--untouch_modules <module names>')
  .option('--config <config name>')
  .option('--param <object string>')
  .option('--rename <new top name>')
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
  noAlwaysComb: program.no_always_comb ? false
  lint: program.lint ? false
}

if program.obfuscate
  global.setObfuscate()

if program.release
  global.setRelease()

if program.untouch_modules
  global.setUntouchModules(program.untouch_modules.split(/,/))

if program.fsdb
  global.setFsdbFormat()

if program.nowave
  global.setNoWave()

if program.noLineno
  global.setNoLineno()

if program.info
  global.setInfo()

if program.prefix?
  global.setPrefix(program.prefix)

if program.force
  global.setForce()

if program.iverilog
  cfg.noAlwaysComb = true

if program.buildsim
  global.setSim()

if program.rename?
  global.setTopName(program.rename)

configBase(cfg)

programParam=[]

if fs.existsSync("./chdl_config.json")
  config_obj = require path.resolve("./chdl_config.json")
  if program.config?
    if config_obj[program.config]?
      programParam = config_obj[program.config]
      log 'Use config name "'+program.config+'" to generate code'
      log 'Parameter',JSON.stringify(programParam)
    else
      log "Can not find config name",program.config
      process.exit()
  else if config_obj.default?
    programParam = config_obj.default
    log 'Use config name "default" to generate code'
    log 'Parameter',JSON.stringify(programParam)

if program.param_file?
  if fs.existsSync(path.resolve(program.param_file))
    programParam= require path.resolve(program.param_file)
  else
    log "Can not find file #{program.param_file}"

if program.param?
  try
    programParam= JSON.parse('['+program.param+']')
  catch e
    log.error e
    
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
        log ("generate code "+fname+".sv").magenta

      if program.flist
        fs.writeFileSync(program.flist,flist.join("\n"),'utf8')
      if program.ncsim
        args=['-64bit','-access +rwc',flist...]
        log "[ncverilog #{args.join(' ')}]"
        spawn('ncverilog',args,{stdio:['pipe',1,2]})
      if program.vcs
        args=['-full64','-R','-debug_access+all','-sverilog','-l','sim.log',flist...]
        log "[vcs #{args.join(' ')}]"
        spawn('vcs',args,{stdio:['pipe',1,2]})
      if program.iverilog
        args=['-o',outDir+'/sim_ivl','-g2012',flist...]
        log "[iverilog #{args.join(' ')}]".yellow
        handler=spawn('iverilog',args,{stdio:['pipe',1,2]})
        handler.on('exit',->
          handler=spawn('vvp',['-livl.log',outDir+'/sim_ivl'],{stdio:['pipe',1,2]})
        )

    catch e
      log.error e
      if (e instanceof SyntaxError)
        lineNum=e.location.first_line-headOver
        log.error (path.basename(fileName)+' '+lineNum+':Error "'+fs.readFileSync(fileName,'utf8').split(/\n/)[lineNum-1].trim()+'"').red
      if (e instanceof TypeError) or (e instanceof ReferenceError)
        lines=e.stack.toString().split(/\s+at\s+/)
        if lines.length>1
          m=lines[1].match(/\((.*)\)/)
          if m?
            [jsfile,lineno]=m[1].split(/:/)
            log.error (path.basename(jsfile)+' '+lineno+':Error "'+fs.readFileSync(jsfile,'utf8').split(/\n/)[Number(lineno-1)].trim()+'"').red
          else
            m=lines[1].match(/(.*):(.*):/)
            if m?
              jsfile=m[1]
              lineno=m[2]
              log.error (path.basename(jsfile)+' '+lineno+':Error "'+fs.readFileSync(jsfile,'utf8').split(/\n/)[Number(lineno-1)].trim()+'"').red


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
log ('Generate code to directory "'+outDir+'"').magenta if outDir?
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
