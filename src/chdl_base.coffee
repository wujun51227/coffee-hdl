_       = require 'lodash'
fs      = require 'fs'
log    =  require 'fancy-log'

Expr    = require('chdl_expr')
Reg     = require('chdl_reg')
BehaveReg     = require('chdl_behave_reg')
Vec     = require('chdl_vec')
Wire    = require('chdl_wire')
Port    = require('chdl_port')
Channel = require('chdl_channel')
Module  = require('chdl_module')
{getPaths,transToJs} = require 'chdl_transpiler_engine'
{packEl,printBuffer,toSignal,toFlatten,__v} = require('chdl_utils')

moduleIndex=0

moduleCache={}

projectDir=''

config={
  autoClock: true
}

getCellList= (inst)->
  p = Object.getPrototypeOf(inst)
  list=({name:k,inst:v} for k,v of p when typeof(v)=='object' and v instanceof Module)
  for i in inst.__cells
    list.push(i) unless _.find(list,(n)-> n.inst.__id==i.inst.__id)
  return _.sortBy(list,['name'])

cell_build = (inst) =>
  inst.__elaboration()
  for i in getCellList(inst)
    i.inst.__link(i.name)
    #log 'Link cell',i.name
    i.inst.__setParentNode(inst)
    if not i.inst.__isCombModule
      if i.inst.__defaultClock==null
        if inst.__defaultClock
          i.inst.__setDefaultClock(inst.__defaultClock)
          i.inst.__addPort(inst.__defaultClock,'input',1)
        else if config.autoClock && i.inst.__autoClock
          i.inst.__setDefaultClock('_clock')
          i.inst.__addPort('_clock','input',1)
      if i.inst.__defaultReset==null
        if inst.__defaultReset
          i.inst.__setDefaultReset(inst.__defaultReset)
          i.inst.__addPort(inst.__defaultReset,'input',1)
        else if config.autoClock && i.inst.__autoClock
          i.inst.__setDefaultReset('_resetn')
          i.inst.__addPort('_resetn','input',1)
    cell_build(i.inst)
  inst.__postElaboration()

get_module_build_name= (inst)->
  baseName=inst.constructor.name
  param=inst.param
  suffix=''
  if getCellList(inst).length>0
    moduleIndex+=1
    suffix='__'+moduleIndex
  s=''
  if inst.param?
    keys=Object.keys(inst.param).sort()
    for k in keys
      v=inst.param[k]
      s+='_'+k+v
  return baseName+s+suffix

code_gen= (inst)=>
  buildName = do ->
    if inst.__specify
      inst.__specifyModuleName
    else
      get_module_build_name(inst)
  inst.__overrideModuleName(buildName)
  log 'Build cell',inst.__getPath(),'(',buildName,')'
  if moduleCache[buildName]?
    return
  else if inst.isBlackBox()
    log 'Warning:',inst.__getPath(),'is blackbox'
    return
  else
    moduleCache[buildName]=true

  for i in getCellList(inst)
    code_gen(i.inst)

  instEnv.register(inst)
  inst.build()
  printBuffer.setName(buildName)
  printBuffer.add '`ifndef UDLY'
  printBuffer.add '`define UDLY 1'
  printBuffer.add '`endif'
  printBuffer.add 'module '+buildName+'('
  printBuffer.add _.map(toFlatten(inst.__ports), (i)=>
    "  "+i[1].portDeclare()
  ).join(",\n")
  printBuffer.add ');'
  printBuffer.blank('//parameter declare')
  printBuffer.add inst.__parameterDeclare()
  printBuffer.blank('//channel declare')
  for [name,channel] in toFlatten(inst.__channels)
    code=channel.verilogDeclare()
    printBuffer.add(code) if code!=''
  printBuffer.blank('//wire declare')
  for [name,wire] in toFlatten(inst.__wires)
    if wire.constructor.name=='Wire'
      printBuffer.add wire.verilogDeclare()
  printBuffer.blank('//port wire declare')
  for [name,port] in toFlatten(inst.__ports)
    unless port.isReg
      printBuffer.add port.verilogDeclare()
  printBuffer.blank('//register declare')
  for [name,reg] in toFlatten(inst.__vecs)
    printBuffer.add reg.verilogDeclare()
    printBuffer.blank()
  printBuffer.blank('//register init and update')
  for [name,reg] in toFlatten(inst.__regs)
    printBuffer.add reg.verilogDeclare()
    printBuffer.add reg.verilogUpdate()
    printBuffer.blank()
  printBuffer.blank('//pipeline declare')
  for i in inst.__pipeRegs
    for [name,reg] in toFlatten(i.pipe)
      printBuffer.add reg.verilogDeclare(true)
  for [name,port] in toFlatten(inst.__ports)
      assignExpr=port.verilogAssign()
      printBuffer.add assignExpr if assignExpr!=''
  printBuffer.blank('//assign logic') if inst.__wireAssignList.length>0
  printBuffer.add i for i in inst.__wireAssignList

  printBuffer.blank('//initial statement') if inst.__initialList.length>0
  for initialList in inst.__initialList
    printBuffer.add 'initial begin'
    for line in initialList
      printBuffer.add '  '+line
    printBuffer.add 'end'
    printBuffer.blank()

  printBuffer.blank('//register update logic') if inst.__alwaysList.length>0
  for [assignList,updateWires] in inst.__alwaysList when assignList? and assignList.length>0
    printBuffer.add 'always_comb begin'
    for i in _.uniqBy(updateWires,(n)=>n.name)
      if i.type=='reg'
        printBuffer.add '  _'+i.name+'='+i.name+';'
      if i.type=='wire'
        if i.pending==null
          printBuffer.add '  _'+i.name+'=0;'
        else
          printBuffer.add '  _'+i.name+'='+i.pending+';'
    if assignList
      for assign in assignList
        printBuffer.add '  '+assign
    printBuffer.add 'end'
    printBuffer.blank()

  printBuffer.blank('//datapath logic')
  for i in inst.__pureAlwaysList
    printBuffer.add "always begin"
    printBuffer.add '  '+i
    printBuffer.add "end"

  for i in inst.__pipeAlwaysList when i.list? and i.list.length>0
    item=_.find(inst.__pipeRegs,(n)=>n.name==i.name)
    hasReset=false
    if 'hasReset' in Object.keys(item.opt)
      if item.opt.hasReset?
        printBuffer.add "always @(posedge #{inst.__defaultClock} or negedge #{item.opt.hasReset}) begin"
        printBuffer.add "  if(#{item.opt.hasReset}==1'b0) begin"
        for regName in i.regs
          printBuffer.add "    #{regName}=0;"
        printBuffer.add "  end"
        hasReset=true
      else if inst.__defaultReset?
        printBuffer.add "always @(posedge #{inst.__defaultClock} or negedge #{inst.__defaultReset}) begin"
        printBuffer.add "  if(#{inst.__defaultReset}==1'b0) begin"
        for regName in i.regs
          printBuffer.add "    #{regName}=0;"
        printBuffer.add "  end"
        hasReset=true
      else
        throw new Error('Can not find reset in module')
        printBuffer.add "always @(posedge #{inst.__defaultClock}) begin"
    else
      printBuffer.add "always @(posedge #{inst.__defaultClock}) begin"
    if hasReset
      printBuffer.add '  else begin'
    for assign in i.list
      if hasReset
        printBuffer.add '    '+assign
      else
        printBuffer.add '  '+assign
    if hasReset
      printBuffer.add '  end'
    printBuffer.add 'end'
    printBuffer.blank()


  printBuffer.blank('//cell instance')
  for i in getCellList(inst)
    paramDeclare=getVerilogParameter(i.inst)
    printBuffer.add i.inst.getModuleName()+paramDeclare+i.name+'('
    if not i.inst.__isCombModule
      if i.inst.__defaultClock
        clockPort=i.inst.__ports[i.inst.__defaultClock]
        if not clockPort.isBinded()
          clockPort.setBindSignal(inst.__defaultClock)
      if i.inst.__defaultReset
        resetPort=i.inst.__ports[i.inst.__defaultReset]
        if not resetPort.isBinded()
          resetPort.setBindSignal(inst.__defaultReset)
    printBuffer.add i.inst._pinConnect(inst).join(",\n")
    printBuffer.add ');'
    printBuffer.blank()

  printBuffer.add 'endmodule'
  printBuffer.blank()
  printBuffer.register(inst)

getVerilogParameter=(inst)->
  if inst.__instParameter==null
    return ' '
  else
    list=[]
    for i in inst.__instParameter
      list.push(".#{i.key}(#{i.value})")
    return " #(\n  "+list.join(",\n  ")+"\n) "

toVerilog=(inst)->
  if (not inst.__isCombModule) and config.autoClock and inst.__autoClock
    if inst.__defaultClock==null
      inst.__setDefaultClock('_clock')
      inst.__addPort('_clock','input',1)
    if inst.__defaultReset==null
      inst.__setDefaultReset('_resetn')
      inst.__addPort('_resetn','input',1)
  cell_build(inst)
  code_gen(inst)
  inst._clean()

input=(width=1)->packEl('port',Port.in(width))

output=(width=1)->packEl('port',Port.out(width))

bind= (name)-> Port.bind(name)
probe= (name)-> Wire.bind(name)

reg= (width=1)-> packEl('reg', Reg.create(width))

behave_reg= (width=1)-> packEl('reg', new BehaveReg(width))

wire= (width=1)->packEl('wire', Wire.create(width))

op_reduce = (list,op)-> list.join(op)

vec= (width,depth)-> Vec.create(width,depth)
channel= (path=null)-> Channel.create(path)

importDesign=(path)->
  list=process.env.NODE_PATH.split(/:/)
  list.push(process.cwd())
  list.push(projectDir)
  list.push(getPaths()...)
  for i in list
    name = path.replace(/\.chdl$/,'')
    if fs.existsSync(i+'/'+name+'.chdl')
      text=fs.readFileSync(i+'/'+name+'.chdl', 'utf-8')
      return transToJs(text,false)
  console.log "Cant find file "+name+".chdl"


instEnv= do ->
  inst=null
  return {
    register: (i)-> inst=i
    getWire: (name,path=null)-> inst._getChannelWire(name,path)
    hasChannel: (name)-> inst.__channels[name]?
    cell: (name)-> inst.__getCell(name)
    infer: (number,offset=0)->
      actWidth=inst.__assignWidth+offset
      if _.isNumber(number)
        __v(actWidth,number)
      else if number.getWidth()>actWidth
        number(0,actWidth)
      else if number.getWidth()<actWidth
        diffWidth=actWidth-number.getWidth()
        return "{#{__v(diffWidth,'0x0')},#{number().refName()}}"
      else
        return number
  }

#module.exports.Wire      = Wire
module.exports.Module    = Module
#module.exports.Port      = Port
#module.exports.Channel   = Channel
#module.exports.Reg       = Reg
module.exports.Expr      = Expr
#module.exports.Vec       = Vec
module.exports.toVerilog   = toVerilog
#module.exports.assign      = assign
#module.exports.assignState = assignState
module.exports.input       = input
module.exports.output      = output
module.exports.bind        = bind
module.exports.probe       = probe
module.exports.channel     = channel
module.exports.reg         = reg
module.exports.behave_reg         = behave_reg
module.exports.wire        = wire
module.exports.vec         = vec
module.exports.op_reduce    = op_reduce
module.exports.channel_wire = instEnv.getWire
module.exports.channel_exist = instEnv.hasChannel
module.exports.infer        = instEnv.infer
module.exports.cell         = instEnv.cell
module.exports.importDesign = importDesign
module.exports.configBase =(cfg)-> config=Object.assign(config,cfg)
module.exports.resetBase   =(path)->
  moduleCache={}
  moduleIndex=0
  projectDir=path
