_       = require 'lodash'
fs      = require 'fs'
log    =  require 'fancy-log'

Expr    = require('chdl_expr')
Reg     = require('chdl_reg')
Vreg     = require('chdl_vreg')
Vec     = require('chdl_vec')
Wire    = require('chdl_wire')
Port    = require('chdl_port')
Channel = require('chdl_channel')
Module  = require('chdl_module')
{stringifyTree} = require "stringify-tree"
{packEl,printBuffer,toSignal,toFlatten,__v} = require('chdl_utils')

moduleIndex=0

moduleCache={}

config={
  autoClock: false
  tree: false
  info: false
  noLineno: false
}

getCellList= (inst)->
  p = Object.getPrototypeOf(inst)
  list=({name:k,inst:v} for k,v of p when typeof(v)=='object' and v instanceof Module)
  for i in inst.__cells
    list.push(i) unless _.find(list,(n)-> n.inst.__id==i.inst.__id)
  return _.sortBy(list,['name'])

cell_build = (inst) =>
  inst.__setConfig(config)
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
  if getCellList(inst).length>0 or inst.__uniq
    moduleIndex+=1
    suffix='__'+moduleIndex
  s=''
  if inst.param?
    keys=Object.keys(inst.param).sort()
    for k in keys
      v=inst.param[k]
      s+='_'+k+v
  return baseName+s+suffix

rhsExpand=(expandItem)->
  if _.isString(expandItem) or _.isNumber(expandItem)
    return expandItem
  else if _.isArray(expandItem)
    str=''
    for item,index in expandItem
      anno= do->
        if item.lineno>=0
          "/*#{item.lineno}*/"
        else
          ""
      v= if _.isArray(item.value) then rhsExpand(item.value) else item.value
      if index==0
        str="(#{item.cond}#{anno})?(#{v}):"
      else if item.cond?
        str+="(#{item.cond}#{anno})?(#{v}):"
      else
        str+="#{v}#{anno}"
    return str

statementGen=(statement)->
  if statement[0]=='assign'
    lhs=statement[1]
    rhs=statement[2]
    lineno=statement[3]
    if lhs.constructor?.name is 'Reg'
      lhs=lhs.dName()
    if lhs.constructor?.name is 'Wire'
      lhs=lhs.refName()
    if lhs.constructor?.name is 'Port'
      lhs=lhs.refName()
    if lineno? and lineno>=0
      "  #{lhs}/*#{lineno}*/ = #{rhsExpand(rhs)};"
    else
      "  #{lhs} = #{rhsExpand(rhs)};"
  else if statement[0]=='assign_delay'
    lhs=statement[1].refName()
    delay=statement[2]
    rhs=statement[3]
    lineno=statement[4]
    if lineno? and lineno>=0
      "  #{lhs}/*#{lineno}*/ = #{delay} #{rhsExpand(rhs)};"
    else
      "  #{lhs} = #{delay} #{rhsExpand(rhs)};"
  else if statement[0]=='end'
    "  end"
  else if statement[0]=='verilog'
    statement[1]
  else if statement[0]=='if'
    cond=statement[1]
    lineno=statement[2]
    if lineno? and lineno>=0
      "  if(#{toSignal cond}) begin /*#{lineno}*/"
    else
      "  if(#{toSignal cond}) begin"
  else if statement[0]=='elseif'
    cond=statement[1]
    lineno=statement[2]
    if lineno? and lineno>=0
      "  else if(#{toSignal cond}) begin /*#{lineno}*/"
    else
      "  else if(#{toSignal cond}) begin"
  else if statement[0]=='else'
    lineno=statement[1]
    if lineno? and lineno>=0
      "  else begin /*#{lineno}*/"
    else
      "  else begin"

code_gen= (inst)=>
  buildName = do ->
    if inst.__specify
      if inst.__uniq
        moduleIndex+=1
        inst.__specifyModuleName+'__'+moduleIndex
      else
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
    "  "+i[1].getName()
  ).join(",\n")
  printBuffer.add ');'
  printBuffer.blank('//parameter declare')
  printBuffer.add inst.__parameterDeclare()
  printBuffer.blank('//port declare')
  _.map(toFlatten(inst.__ports), (i)=>
    printBuffer.add i[1].portDeclare()+";"
  )
  printBuffer.blank('//channel declare')
  for [name,channel] in toFlatten(inst.__channels)
    code=channel.verilogDeclare()
    printBuffer.add(code) if code!=''
  printBuffer.blank('//wire declare')
  for [name,wire] in toFlatten(inst.__wires)
    if wire.constructor.name=='Wire'
      printBuffer.add wire.verilogDeclare()
  for [name,wire] in toFlatten(inst.__local_wires)
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
  for [name,reg] in toFlatten(inst.__local_regs)
    printBuffer.add reg.verilogDeclare()
    printBuffer.add reg.verilogUpdate()
    printBuffer.blank()
  printBuffer.blank('//assign logic') if inst.__wireAssignList.length>0
  for statement in inst.__wireAssignList
    if statement[0]=='reg'
      width=statement[1]
      name=statement[2]
      lineno=statement[3]
      if lineno? and lineno>=0
        printBuffer.add "reg #{name}/*#{lineno}*/;"
      else
        printBuffer.add "reg #{name};"
    else if statement[0]=='assign'
      lhs=statement[1]
      rhs=statement[2]
      lineno=statement[3]
      if lhs.constructor?.name is 'Reg'
        lhs=lhs.dName()
      else if lhs.constructor?.name is 'Wire'
        lhs=lhs.refName()
      else if lhs.constructor?.name is 'Port'
        lhs=lhs.refName()
      if lineno? and lineno>=0
        printBuffer.add "assign #{lhs}/*#{lineno}*/ = #{rhsExpand(rhs)};"
      else
        printBuffer.add "assign #{lhs} = #{rhsExpand(rhs)};"
    else if statement[0]=='assign_delay'
      lhs=statement[1].refName()
      delay=statement[2]
      rhs=statement[3]
      lineno=statement[4]
      if lineno? and lineno>=0
        printBuffer.add "assign #{lhs}/*#{lineno}*/ = #{delay} #{rhsExpand(rhs)};"
      else
        printBuffer.add "assign #{lhs} = #{delay} #{rhsExpand(rhs)};"

  printBuffer.blank('//event declare') unless _.isEmpty(inst.__trigMap)
  for name in Object.keys(inst.__trigMap)
    printBuffer.add "event #{name};"
  printBuffer.blank('//initial statement') if inst.__initialList.length>0
  for seqList in inst.__initialList when seqList.length>0
    printBuffer.add "initial begin"
    for seq in seqList
      initSegmentList = seq.bin
      seqName= seq.name ? ''
      printBuffer.add "  $display(\"start sequence #{seqName}\");"
      for initSegment in initSegmentList
        item = initSegment
        if item.type=='delay'
          if _.isNumber(item.delay)
            printBuffer.add "  ##{item.delay}"
        if item.type=='posedge'
          printBuffer.add "  @(posedge #{item.signal.getName()});"
        if item.type=='negedge'
          printBuffer.add "  @(negedge #{item.signal.getName()});"
        if item.type=='wait'
          printBuffer.add "  wait(#{item.expr})"
        if item.type=='event'
          printBuffer.add "  -> #{item.event};"
        if item.type=='trigger'
          printBuffer.add "  @(#{item.signal});"
        for statement in item.list
          printBuffer.add statementGen(statement)
    printBuffer.add "end"
    printBuffer.blank()

  printBuffer.blank('//forever statement') if inst.__foreverList.length>0
  for seqList in inst.__foreverList when seqList.length>0
    printBuffer.add "always begin"
    for seq in seqList
      initSegmentList = seq.bin
      for initSegment in initSegmentList
        item = initSegment
        if item.type=='delay'
          if _.isNumber(item.delay)
            printBuffer.add "  ##{item.delay}"
        if item.type=='posedge'
          printBuffer.add "  @(posedge #{item.signal.getName()});"
        if item.type=='negedge'
          printBuffer.add "  @(negedge #{item.signal.getName()});"
        if item.type=='wait'
          printBuffer.add "  wait(#{item.expr})"
        if item.type=='event'
          printBuffer.add "  -> #{item.event};"
        if item.type=='trigger'
          printBuffer.add "  @(#{item.signal});"
        for statement in item.list
          printBuffer.add statementGen(statement)
    printBuffer.add "end"
    printBuffer.blank()

  printBuffer.blank('//register update logic') if inst.__alwaysList.length>0
  for [assignList,updateWires,lineno] in inst.__alwaysList when assignList? and assignList.length>0
    if lineno? and lineno>=0
      printBuffer.add 'always_comb begin'+"/*#{lineno}*/"
    else
      printBuffer.add 'always_comb begin'
    for i in _.uniqBy(updateWires,(n)=>n.name)
      if i.type=='reg'
        printBuffer.add '  '+i.inst.dName()+'='+i.inst.refName()+';'
      if i.type=='wire'
        if i.pending==null
          printBuffer.add '  '+i.inst.refName()+'=0;'
        else
          printBuffer.add '  '+i.inst.refName()+'='+i.pending+';'
    if assignList
      for statement in assignList
        printBuffer.add statementGen(statement)
    printBuffer.add 'end'
    printBuffer.blank()

  printBuffer.blank('//sequence logic')
  for [seqBlockList,lineno] in inst.__sequenceAlwaysList
    for seqBlock in seqBlockList
      printBuffer.blank("//sequence #{seqBlock.name} #{lineno}")
      stateReg=seqBlock.stateReg
      nextState=seqBlock.nextState
      updateWires=seqBlock.update
      printBuffer.add "always_combo begin"
      printBuffer.add "  #{nextState.getName()}=#{stateReg.getName()}"
      for i,index in seqBlock.bin
        console.log i.isLast,i.type
        if index==0
          lastState=stateReg.getState('idle')
          lastBin=null
        else
          lastState=stateReg.getState(seqBlock.bin[index-1].id)
          lastBin=seqBlock.bin[index-1]
        currentState=stateReg.getState(i.id)
        if i.type=='next'
          printBuffer.add "  if(#{stateReg.getName()}==#{lastState}) begin"
          if i.expr==null
            printBuffer.add "    #{nextState.getName()}=#{currentState};"
          else
            printBuffer.add "    if(#{i.expr}) begin"
            printBuffer.add "      #{nextState.getName()}=#{currentState};"
            printBuffer.add "    end"
          printBuffer.add "  end"
        else if i.type=='posedge' or i.type=='negedge' or i.type=='wait'
          printBuffer.add "  if(#{stateReg.getName()}==#{lastState}) begin"
          printBuffer.add "    if(#{i.expr}) begin"
          printBuffer.add "      #{nextState.getName()}=#{currentState};"
          printBuffer.add "    end"
          if i.isLast
            printBuffer.add "    else begin"
            printBuffer.add "      #{nextState.getName()}=#{stateReg.getState('idle')};"
            printBuffer.add "    end"
          printBuffer.add "  end"
      printBuffer.add "end"
      printBuffer.add "always_combo begin"
      for i in _.uniqBy(updateWires,(n)=>n.name)
        if i.type=='reg'
          printBuffer.add '  _'+i.name+'='+i.name+';'
        if i.type=='wire'
          if i.pending==null
            printBuffer.add '  _'+i.name+'=0;'
          else
            printBuffer.add '  _'+i.name+'='+i.pending+';'
      for i,index in seqBlock.bin when i.list.length>0
        printBuffer.add "  if(#{stateReg.isState(i.id)}) begin"
        for statement in i.list
          printBuffer.add statementGen(statement)
        printBuffer.add "  end"
      printBuffer.add "end"

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
    [pinConn,pinAssigns]=i.inst._pinConnect(inst)
    printBuffer.add pinConn.join(",\n")
    printBuffer.add ');'
    printBuffer.blank()

    if pinAssigns.length>0
      pinAssignList=[]
      for pinAssign in pinAssigns
        hit= _.find(inst.__pinAssign,{to:pinAssign.to})
        if hit?
          pinAssignList.push({
            from: pinAssign.from
            to: hit.from
          })
        else
          pinAssignList.push(pinAssign)
      _.map(pinAssignList,(n)->
        printBuffer.add "assign #{n.to} = #{n.from};"
      )
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
  if config.tree
    console.log(stringifyTree({name:inst.getModuleName(),inst:inst}, ((t) -> t.name+' ('+t.inst.getModuleName()+')'), ((t) -> getCellList(t.inst))))
  inst._clean()

input=(width=1)->packEl('port',Port.in(width))

output=(width=1)->packEl('port',Port.out(width))

bind= (name)-> Port.bind(name)
probe= (name)-> Wire.bind(name)

reg= (width=1)-> packEl('reg', Reg.create(width))

vreg= (width=1)-> packEl('reg', new Vreg(width))

wire= (width=1)->packEl('wire', Wire.create(width))

vec= (width,depth)-> Vec.create(width,depth)
channel= (path=null)-> Channel.create(path)

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

module.exports.Module    = Module
module.exports.Expr      = Expr
module.exports.toVerilog   = toVerilog
module.exports.input       = input
module.exports.output      = output
module.exports.bind        = bind
#module.exports.probe       = probe
module.exports.channel     = channel
module.exports.reg         = reg
module.exports.vreg        = vreg
module.exports.wire        = wire
module.exports.vec         = vec
module.exports.channel_wire = instEnv.getWire
module.exports.channel_exist = instEnv.hasChannel
module.exports.infer        = instEnv.infer
module.exports.cell         = instEnv.cell
module.exports.configBase =(cfg)-> config=Object.assign(config,cfg)
module.exports.getConfig  = (v)-> config[v]
module.exports.resetBase   =(path)->
  moduleCache={}
  moduleIndex=0
