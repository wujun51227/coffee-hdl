#!/usr/bin/env coffee

require('json5/lib/register')
JSON5    = require('json5')

fs = require 'fs'
path = require 'path'
_ = require 'lodash'
log = require 'fancy-log'
colors = require 'colors'
{simBuffer,printBuffer,dumpBuffer}=require 'chdl_utils'
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
  .option('--tb <module name>')
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
  .option('--config_file  <config file name>')
  .option('--param <object string>')
  .option('--rename <new top name>')
  .option('--debug')
  .parse(process.argv)

debug = program.debug ? false

if program.new?
  moduleName = program.new
  code = """
_ = require 'lodash'
#cell = importDesign './foo.chdl'
class #{moduleName} extends Module
  constructor: ->
    super()

    #CellMap([
    #  { name: 'u0_cell',  inst: new cell() }
    #])

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
  log ("Write to file ./#{moduleName}.chdl").yellow
  process.exit()

if program.tb?
  moduleFile = program.tb
  moduleName = path.basename(moduleFile,'.chdl')
  code = """
_ = require 'lodash'
dut = importDesign '#{moduleFile}'
class tb_#{moduleName} extends Module
  constructor: ->
    super()

    Mixin importLib('chdl_testbench_lib.chdl')
    Mixin importLib('verilog_helpers.chdl')

    CellMap([
      { name: 'dut',  inst: new dut() }
    ])

    Channel(
      dut_channel: @mold(@dut)
    )

    Reg(
      clk: vreg()
      rstn: vreg().init(1)
    )

    @setDefaultClock('clk')
    @setDefaultReset('rstn')


  build: ->
    @create_clock(@clk,10)  # clock period is 10ns
    @create_resetn(@rstn,10,100) # rstn assert from 10ns,hold 100ns
    @dump_wave("dump_#{moduleName}")

    dev= @dut_channel

    fifo=@tb_fifo_gen(32,1024,'fifo') # create a fifo 32 width,1024 depth
    # [fifo api]
    # fifo.push(data)
    # fifo.pop()
    # fifo.$front()
    # fifo.$tail()
    # fifo.$isEmpty()
    # fifo.$isFull()
    # fifo.$getSize()
    Net signal = 1
    count=vreg(32)

    forever
      seq=$sequence()
      seq.polling(@clk,$(signal)) =>
      seq.delay(200) =>
        @display("in forever %x",$(signal))
      seq.end()

    initial
      seq=$sequence()
      seq.init =>
      seq.delay(200) =>
        $while(count>0)
          assign count=count-1
      seq.do =>
      seq.polling(@clk,$(signal)) =>
      seq.posedge(@clk) =>
      seq.negedge(@clk) =>
      seq.wait($(@clk)) =>
      seq.delay(1) =>
        @display("simulation finish %x",$(signal))
        @assert_report()
        @sim_finish()
      seq.end()

module.exports=tb_#{moduleName}
"""
  fs.writeFileSync("./tb_#{moduleName}.chdl",code,'utf8')
  log ("Write to file ./tb_#{moduleName}.chdl").yellow
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

config_obj=null
if program.config_file?
  config_obj = require path.resolve(program.config_file)
else if fs.existsSync("./chdl_config.json5")
  config_obj = require path.resolve("./chdl_config.json5")
else if fs.existsSync("./chdl_config.json")
  config_obj = require path.resolve("./chdl_config.json")

if config_obj?
  if program.config?
    programParam = _.get(config_obj,program.config,null)
    if programParam?
      log 'Use config name "'+program.config+'" to generate code'
      log 'Parameter',JSON.stringify(programParam)
    else
      log "Can not find config name",program.config
      process.exit()

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
      for i,index in dumpBuffer.getBin()
        code= i.list.join("\n")
        fname= do ->
          if outDir?
            outDir+'/'+i.name
          else
            i.name
        fs.writeFileSync(fname+'.dump.json',code,'utf8')
      for i,index in printBuffer.getBin()
        code= i.list.join("\n")
        fname= do ->
          if outDir?
            outDir+'/'+i.name
          else
            i.name
        flist.push(path.resolve(fname)+'.sv')
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
      if (e instanceof SyntaxError)
        errStr=e.toString()
        log.error errStr.red
        lineNum=e.location.first_line-headOver
        for i in _.range(10)
          line_no=lineNum+i
          log.error (path.basename(fileName)+' '+line_no+': "'+fs.readFileSync(fileName,'utf8').split(/\n/)[line_no-1].trim()+'"').red
      else if (e instanceof TypeError) or (e instanceof ReferenceError)
        log.error e
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
      else
        log.error e


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
    dumpBuffer.clearBin()
    simBuffer.clearBin()
    banner(fileName)
    processFile(fileName,outDir.replace(/\/$/,''))
  )
