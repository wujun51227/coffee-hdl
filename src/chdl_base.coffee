_      = require 'lodash'
log    = require 'fancy-log'
colors = require 'colors'
fs     = require 'fs'

Expr    = require('chdl_expr')
Reg     = require('chdl_reg')
Vec     = require('chdl_vec')
Wire    = require('chdl_wire')
Port    = require('chdl_port')
Channel = require('chdl_channel')
Module  = require('chdl_module')
Vnumber  = require('chdl_number')
Verilog  = require('verilog')
{table} = require 'table'
global  = require('chdl_global')
{stringifyTree} = require "stringify-tree"
{getValue,packEl,simBuffer,printBuffer,dumpBuffer,toSignal,toFlatten,syncType} = require('chdl_utils')
{cdcAnalysis,buildClkTree}= require 'chdl_cdc'

moduleIndex=0

moduleCache={}

globalModuleCache={}

config={
  #autoClock: false
  tree: false
  noAlwaysComb: false
  lint: false
}

arr=[
  'abcdefghijklmnopqrstuvwxyz'...
  'ABCDEFGHIJKLMNOPQRSTUVWXYZ'...
]

dict=[arr...]

obscure_map={}

do =>
  dict.sort(()=>
    return 0.5 - Math.random()
  )
  for i,index in arr
    obscure_map[i]=dict[index]

blur=(s)=>
  if global.getObfuscate()
    out=[]
    for i in [s...]
      if obscure_map[i]?
        out.push obscure_map[i]
      else
        out.push i
    return out.join('')
  else if global.getPrefix()
    prefix = global.getPrefix()
    return prefix+'__'+s
  else
    return s

getCellList= (inst)->
  p = Object.getPrototypeOf(inst)
  list=({name:k,inst:v} for k,v of p when typeof(v)=='object' and v instanceof Module)
  for i in inst.__cells
    list.push(i) unless _.find(list,(n)-> n.inst.__id==i.inst.__id)
  return _.sortBy(list,['name'])

cell_build = (inst) =>
  inst._elaboration()
  for i in getCellList(inst)
    i.inst._link(i.name)
    #log 'Link cell',i.name
    i.inst._setParentNode(inst)
    cell_build(i.inst)
  inst._postElaboration()

get_module_build_name= (inst)->
  baseName=inst.constructor.name
  suffix=''
  if getCellList(inst).length>0 or inst.__uniq
    moduleIndex+=1
    suffix='__'+moduleIndex
  s=''
  return baseName+s+suffix

lineComment=(lineno)-> " /* #{lineno} */ "

sharpToDot = (s)->  s.replace(/#/g,'.')

rhsExpand=(expandItem)->
  if expandItem?.__type == 'expr'
    cntExpr()
    return {
      code: sharpToDot(expandItem.e.str)+expandItem.append
      w: expandItem.e.wstr
      driven: _.clone(expandItem.e.driven)
    }
  else if _.isArray(expandItem)
    str=''
    w=''
    driven=[]
    cntCond(expandItem.length)
    for item,index in expandItem
      anno= do->
        if item.lineno>=0
          "#{lineComment(item.lineno)}"
        else
          ""
      v= rhsExpand(item.value)
      if not v?
        log("Error:assign expr is undefined #{anno}".red)
        throw new Error("assign expr is undefined #{anno}")
      if index==0
        str="(#{item.cond.str}#{anno})?(#{v.code}):"
        dList=_.clone(item.cond.driven)
        driven.push(dList...)
      else if item.cond?
        str+="(#{item.cond.str}#{anno})?(#{v.code}):"
        dList=_.clone(item.cond.driven)
        driven.push(dList...)
      else
        str+="#{v.code}#{anno}"
      if index==0
        w=v.w
      else
        w=w+'|'+v.w
      driven.push(_.clone(v.driven)...)
    return {
      code:str
      w: w
      driven: driven
    }

checkAssignWidth=(lhs,rhsInfo,lineno)->
  return if config.lint==false
  return if getLint('widthCheckLevel')==0
  return if rhsInfo.w.match(/^"/)
  try
    rhsWidth=Number(Verilog.parser.parse(rhsInfo.w))
    lhsWidth=lhs.getWidth()
    #console.log rhsInfo.code,rhsInfo.w,rhsWidth,lhs.getWidth()
    if getLint('widthCheckLevel')==1
      if lhsWidth<rhsWidth
        log "Error: width overflow at line #{lineno} assign #{rhsWidth} to #{lhs.hier} #{lhs.getWidth()}".red
    else if getLint('widthCheckLevel')==2
      if lhsWidth!=rhsWidth
        log "Error: width mismatch at line #{lineno} assign #{rhsWidth} to #{lhs.hier} #{lhs.getWidth()}".red
  catch e
    console.log 'Parse error:',lineno,lhs.hier,instEnv.get()._getModuleName()
    console.log e


statementGen=(buffer,statement,cond_stack=[],sig_driven_list=[])->
  stateType=statement[0]
  if stateType=='assign'
    lhs=statement[1]
    rhs=statement[2]
    lineno=statement[3]
    lhsName=''
    checkPoint=false
    if lhs.constructor?.name is 'Reg'
      lhsName=lhs.getDwire().refName()
      checkPoint=true
    else if lhs.constructor?.name is 'Wire'
      lhsName=lhs.refName()
      if lhs.getSync()?
        checkPoint=true
    else if lhs.constructor?.name is 'Port'
      lhsName=lhs.refName()
      if lhs.getType()=='output'
        checkPoint=true
      if lhs.isReg
        lhsName=lhs.shadowReg.getDwire().refName()
    else if lhs.constructor?.name is 'VecMember'
      lhsName=lhs.refName()
    else
      throw new Error("Unknown lhs type")
    space="  ".repeat(cond_stack.length+1)
    conds= if cond_stack.length>0 then _.last(cond_stack) else []
    if lineno? and lineno>=0
      rhsInfo=rhsExpand(rhs)
      sig_driven_list.push({key:lhs.getElId(),checkPoint:checkPoint,inst:lhs,driven:rhsInfo.driven,conds:conds})
      if _.isNil(rhsInfo) or _.isNil(rhsInfo.code)
        throw new Error("assign to #{lhsName} code is null at #{lineno}".red)
      buffer.add space+"#{toSignal lhsName}#{lineComment(lineno)}= #{rhsInfo.code};"
      checkAssignWidth(lhs,rhsInfo,lineno)
    else
      rhsInfo=rhsExpand(rhs)
      sig_driven_list.push({key:lhs.getElId(),checkPoint:checkPoint,inst:lhs,driven:rhsInfo.driven,conds:conds})
      if _.isNil(rhsInfo) or _.isNil(rhsInfo.code)
        throw new Error("assign to #{lhsName} code is null".red)
      buffer.add space+"#{toSignal lhsName} = #{rhsInfo.code};"
      checkAssignWidth(lhs,rhsInfo,lineno)
  else if stateType=='end'
    buffer.add "  end"
  else if stateType=='cond_end'
    space="  ".repeat(cond_stack.length)
    buffer.add space+"end"
  else if stateType=='verilog'
    buffer.add statement[1]
  else if stateType=='while'
    cond=statement[1]
    lineno=statement[2]
    if lineno? and lineno>=0
      buffer.add "  while(#{toSignal cond.str}) begin #{lineComment(lineno)}"
    else
      buffer.add "  while(#{toSignal cond.str}) begin"
  else if stateType=='if'
    cond=statement[1]
    cond_driven = []
    if cond_stack.length>0
      cond_driven.push(_.last(cond_stack)...)
    cond_driven.push(_.clone(cond.driven))
    cond_stack.push(cond_driven)
    space="  ".repeat(cond_stack.length)
    lineno=statement[2]
    cntCond(1)
    if lineno? and lineno>=0
      buffer.add space+"if(#{toSignal cond.str}) begin #{lineComment(lineno)}"
    else
      buffer.add space+"if(#{toSignal cond.str}) begin"
  else if stateType=='elseif'
    cntCond(1)
    cond=statement[1]
    cond_driven = _.last(cond_stack)
    dList=_.last(cond_driven)
    dList.push(cond.driven...)
    space="  ".repeat(cond_stack.length)
    lineno=statement[2]
    if lineno? and lineno>=0
      buffer.add space+"else if(#{toSignal cond.str}) begin #{lineComment(lineno)}"
    else
      buffer.add space+"else if(#{toSignal cond.str}) begin"
  else if stateType=='else'
    cntCond(1)
    lineno=statement[1]
    space="  ".repeat(cond_stack.length)
    if lineno? and lineno>=0
      buffer.add space+"else begin #{lineComment(lineno)}"
    else
      buffer.add space+"else begin"
  else if stateType=='delay'
    item = statement[1]
    if _.isNumber(item.delay)
      if item.delay!=null
        buffer.add "  ##{item.delay}"
      for i in item.list
        statementGen(buffer,i)
  else if stateType=='flow_delay'
    if _.isNumber(statement[2]) and statement[2]!=null
      buffer.add "  ##{statement[2]}"
  else if stateType=='flow_posedge'
    buffer.add "  @(posedge #{statement[2]});"
  else if stateType=='flow_negedge'
    buffer.add "  @(negedge #{statement[2]});"
  else if stateType=='flow_wait'
    buffer.add "  wait(#{statement[2].e.str});"
  else if stateType=='flow_event'
    buffer.add "  -> #{statement[2]};"
  else if stateType=='flow_trigger'
    buffer.add "  @(#{statement[2]});"
  else if stateType=='event'
    item = statement[1]
    buffer.add "  -> #{item.event};"
  else if stateType=='trigger'
    item = statement[1]
    buffer.add "  @(#{item.signal});"
    for i in item.list
      statementGen(buffer,i)
  else if stateType=='polling'
    item = statement[1]
    buffer.add "  while(#{item.active}) begin"
    buffer.add "    @(posedge #{item.signal});"
    buffer.add "    if(#{item.expr.e.str}) begin"
    buffer.add "      #{item.active} = 0;"
    buffer.add "    end;"
    buffer.add "  end;"
    for i in item.list
      statementGen(buffer,i)
  else if stateType=='posedge'
    item = statement[1]
    buffer.add "  @(posedge #{item.signal});"
    for i in item.list
      statementGen(buffer,i)
  else if stateType=='negedge'
    item = statement[1]
    buffer.add "  @(negedge #{item.signal});"
    for i in item.list
      statementGen(buffer,i)
  else if stateType=='wait'
    item = statement[1]
    buffer.add "  wait(#{item.expr.e.str})"
    for i in item.list
      statementGen(buffer,i)
  else if stateType=='array_init'
    array_el=statement[1]
    file_type=statement[2][0]
    file_path=statement[2][1]
    oomr=statement[2][2]
    if oomr
      array_path=array_el.oomrName()
    else
      array_path=array_el.getName()
    if file_type=='hex'
      buffer.add "  $readmemh(#{file_path},#{array_path});"
    else
      throw new Error("arrays init format #{file_type} undefined".red)
  else if stateType=='endif'
    cond_stack.pop()
  else
    throw new Error("can not find type #{stateType}")

buildSim= (buildName,inst)=>
  #console.log(JSON.stringify(inst._dumpWire(),null,'  '))
  #console.log(JSON.stringify(inst._dumpPort(),null,'  '))
  #console.log(JSON.stringify(inst._dumpReg(),null,'  '))
  #console.log(JSON.stringify(inst._dumpVar(),null,'  '))
  #console.log(JSON.stringify(inst._dumpCell(),null,'  '))

  simBuffer.setName(buildName,inst)
  simBuffer.add 'const '+buildName+' = { }'
  simBuffer.add _.map(toFlatten(inst.__ports), (i)=>
    "_.set(#{buildName},'#{i[0]}',rxGen(#{i[1].getWidth()}))"
  ).join("\n")
  simBuffer.flush()
###
  simPackage={
    name    : buildName
    port    : inst._dumpPort()
    reg     : inst._dumpReg()
    wire    : inst._dumpWire()
    var     : inst._dumpVar()
    event   : inst._dumpEvent()
    cell    : inst._dumpCell()
  }
###

code_gen= (inst,allInst,first=false)=>
  if first
    inst._setProperty({uniq:false})
  buildName = inst._getBuildName()

  if first and (!inst._isCompany()) and global.getTopName()?
    buildName = global.getTopName()

  if inst.__uniq
    moduleIndex += 1
    buildName = buildName+'__'+moduleIndex
  if first==false
    if not global.getUntouchModules().includes(inst.constructor.name)
      buildName=blur(buildName)
  inst._overrideModuleName(buildName)
  log ('Build cell '+inst._getPath()+' ( '+buildName+' )').green
  if moduleCache[buildName]?
    return
  else if inst._isBlackBox()
    log 'Warning:',inst._getPath(),'is blackbox'
    return
  else
    moduleCache[buildName]=true

  sig_driven_tree={inst:inst,list:[],children:[]}
  for i in getCellList(inst)
    inst_sig_driven=code_gen(i.inst,allInst)
    sig_driven_tree.children.push(inst_sig_driven)

  driven_list=sig_driven_tree.list

  if inst.dump?
    dumpBuffer.setName(buildName,null)
    dumpBuffer.add JSON.stringify(inst.dump(),null,2)
    dumpBuffer.flush()
    #fs.writeFileSync(buildName+'.dump.json',JSON.stringify(inst.dump(),null,2),'utf8')

  instEnv.register(inst)
  allInst.push(inst) if allInst?

  channelWireList=[]
  for [name,channel] in toFlatten(inst.__channels)
    code=channel.verilogDeclare()
    channelWireList.push(code) if code!=''

  for [name,item] in toFlatten(inst.__channels)
    if item.probeChannel==null
      if item.wireMap?
        _.set(inst,name,item.wireMap)
      else
        _.set(inst,name,item.portMap)

  inst.build()
  if global.getSim()
    log(("Build sim "+buildName).green)
    buildSim(buildName,inst)
  printBuffer.setName(buildName,inst)
  printBuffer.add '`ifndef UDLY'
  printBuffer.add '`define UDLY 1'
  printBuffer.add '`endif'
  if global.getIfdefProtect()
    printBuffer.add '`ifndef _CHDL_'+buildName.toUpperCase()+'_'
    printBuffer.add '`define _CHDL_'+buildName.toUpperCase()+'_'
  printBuffer.add 'module '+buildName+'('
  printBuffer.add _.map(toFlatten(inst.__ports), (i)=>
    "  "+i[1].getName()
  ).join(",\n")
  printBuffer.add ');'
  printBuffer.blank('//parameter declare')
  for i in inst.__moduleParameter
    printBuffer.add i.verilogDeclare(false)
  printBuffer.blank('//port declare')
  _.map(toFlatten(inst.__ports), (i)=>
    printBuffer.add i[1].portDeclare()+";"
  )
  printBuffer.blank('//channel declare')
  for i in channelWireList
    printBuffer.add(i)
  printBuffer.blank('//wire declare')
  for [name,wire] in toFlatten(inst.__wires)
    if wire.constructor.name=='Wire'
      printBuffer.add wire.verilogDeclare()
  for [name,wire] in toFlatten(inst.__local_wires)
    if wire.constructor.name=='Wire' and wire.local
      printBuffer.add wire.verilogDeclare()
  printBuffer.blank('//port wire declare')
  for [name,port] in toFlatten(inst.__ports)
    unless port.isReg
      printBuffer.add port.verilogDeclare()
  printBuffer.blank('//register declare')
  for [name,reg] in toFlatten(inst.__local_vecs)
    printBuffer.add reg.verilogDeclare()
    printBuffer.blank()
  printBuffer.blank('//register init and update')
  for [name,reg] in toFlatten(inst.__regs) when reg.isVirtual()
    printBuffer.add reg.verilogDeclare()
    printBuffer.add reg.verilogUpdate()
    printBuffer.blank()
  for [name,reg] in toFlatten(inst.__regs) when not reg.isVirtual()
    printBuffer.add reg.verilogDeclare()
    printBuffer.add reg.verilogUpdate()
    printBuffer.blank()
  for [name,reg] in toFlatten(inst.__local_regs)
    if reg.local
      printBuffer.add reg.verilogDeclare()
      printBuffer.add reg.verilogUpdate()
      printBuffer.blank()
  printBuffer.blank('//assign logic') if inst.__wireAssignList.length>0
  for statement in inst.__wireAssignList
    if statement[0]=='reg'
      name=statement[2]
      lineno=statement[3]
      if lineno? and lineno>=0
        printBuffer.add "reg #{name}#{lineComment(lineno)};"
      else
        printBuffer.add "reg #{name};"
    else if statement[0]=='array_set'
      lhs=statement[1]
      lhsName=lhs.refName()

      cond=statement[2][0]
      condInfo=rhsExpand(cond)
      if _.isNil(condInfo) or _.isNil(condInfo.code)
        throw new Error("arrays set to #{lhsName} condition is null".red)

      rhs=statement[2][1]
      rhsInfo=rhsExpand(rhs)
      if _.isNil(rhsInfo) or _.isNil(rhsInfo.code)
        throw new Error("arrays set to #{lhsName} value is null".red)

      clock=statement[2][2]

      printBuffer.add "always @(posedge #{clock})  begin"+"#{lineComment(lineno)}"
      printBuffer.add "  if(#{condInfo.code}) begin"
      printBuffer.add "    #{lhsName} <= #{rhsInfo.code};"
      printBuffer.add "  end"
      printBuffer.add "end"
    else if statement[0]=='array_get'
      lhs=statement[1]
      lhsName=lhs.refName()

      cond=statement[2][0]
      condInfo=rhsExpand(cond)
      if _.isNil(condInfo) or _.isNil(condInfo.code)
        throw new Error("arrays get to #{lhsName} condition is null".red)

      target=statement[2][1]
      targetName=target.refName()

      clock=statement[2][2]

      printBuffer.add "always @(posedge #{clock})  begin"+"#{lineComment(lineno)}"
      printBuffer.add "  if(#{condInfo.code}) begin"
      printBuffer.add "    #{targetName} <= #{lhsName};"
      printBuffer.add "  end"
      printBuffer.add "end"
    else if statement[0]=='assign'
      lhs=statement[1]
      rhs=statement[2]
      lineno=statement[3]
      lhsName=''
      checkPoint=false
      if lhs.constructor?.name is 'Reg'
        lhsName=lhs.getDwire().refName()
        checkPoint=true
      else if lhs.constructor?.name is 'Wire'
        lhsName=lhs.refName()
        if lhs.getSync()?
          checkPoint=true
      else if lhs.constructor?.name is 'Port'
        lhsName=lhs.refName()
        if lhs.getType()=='output'
          checkPoint=true
        if lhs.isReg
          lhsName=lhs.shadowReg.getDwire().refName()
      else
        throw new Error('Unknown lhs type')
      if lineno? and lineno>=0
        rhsInfo=rhsExpand(rhs)
        if inst.__isCombModule
          driven_list.push({key:lhs.getElId(),checkPoint:false,inst:lhs,driven:rhsInfo.driven,conds:[]})
        else
          driven_list.push({key:lhs.getElId(),checkPoint:checkPoint,inst:lhs,driven:rhsInfo.driven,conds:[]})
        if _.isNil(rhsInfo) or _.isNil(rhsInfo.code)
          throw new Error("assign to #{lhsName} is null at #{lineno}".red)
        printBuffer.add "assign #{toSignal lhsName}#{lineComment(lineno)}= #{rhsInfo.code};"
        checkAssignWidth(lhs,rhsInfo,lineno)
      else
        rhsInfo=rhsExpand(rhs)
        if inst.__isCombModule
          driven_list.push({key:lhs.getElId(),checkPoint:false,inst:lhs,driven:rhsInfo.driven,conds:[]})
        else
          driven_list.push({key:lhs.getElId(),checkPoint:checkPoint,inst:lhs,driven:rhsInfo.driven,conds:[]})
        if _.isNil(rhsInfo) or _.isNil(rhsInfo.code)
          throw new Error("assign to #{lhsName} is null".red)
        printBuffer.add "assign #{toSignal lhsName} = #{rhsInfo.code};"
        checkAssignWidth(lhs,rhsInfo,lineno)

  printBuffer.blank('//event declare') unless _.isEmpty(inst.__trigMap)
  for name in Object.keys(inst.__trigMap)
    printBuffer.add "event #{name};"
  printBuffer.blank('//initial statement') if inst.__initialList.length>0
  for seqList in inst.__initialList when seqList.length>0
    printBuffer.add "initial begin"
    for seq in seqList
      initSegmentList = seq.bin
      seqName= seq.name ? ''
      if seqName!=''
        printBuffer.add "  $display(\"start sequence #{seqName}\");"
      for initSegment in initSegmentList
        item = initSegment
        if item.type=='delay'
          if _.isNumber(item.delay)
            printBuffer.add "  ##{item.delay}"
        if item.type=='polling'
          printBuffer.add "  #{item.active} = 1;"
          printBuffer.add "  while(#{item.active}) begin"
          printBuffer.add "    @(posedge #{item.signal});"
          printBuffer.add "    if(#{item.expr.e.str}) begin"
          printBuffer.add "      #{item.active} = 0;"
          printBuffer.add "    end;"
          printBuffer.add "  end;"
        if item.type=='posedge'
          printBuffer.add "  @(posedge #{item.signal});"
        if item.type=='after_posedge'
          printBuffer.add "  @(posedge #{item.signal});"
          printBuffer.add "  ##{item.delay};"
        if item.type=='negedge'
          printBuffer.add "  @(negedge #{item.signal});"
        if item.type=='wait'
          printBuffer.add "  wait(#{item.expr.e.str})"
        if item.type=='event'
          printBuffer.add "  -> #{item.event};"
        if item.type=='trigger'
          printBuffer.add "  @(#{item.signal});"
        for statement in item.list
          statementGen(printBuffer,statement)
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
        if item.type=='polling'
          printBuffer.add "  #{item.active} = 1;"
          printBuffer.add "  while(#{item.active}) begin"
          printBuffer.add "    @(posedge #{item.signal});"
          printBuffer.add "    if(#{item.expr.e.str}) begin"
          printBuffer.add "      #{item.active} = 0;"
          printBuffer.add "    end;"
          printBuffer.add "  end;"
        if item.type=='posedge'
          printBuffer.add "  @(posedge #{item.signal});"
        if item.type=='after_posedge'
          printBuffer.add "  @(posedge #{item.signal});"
          printBuffer.add "  ##{item.delay};"
        if item.type=='negedge'
          printBuffer.add "  @(negedge #{item.signal});"
        if item.type=='wait'
          printBuffer.add "  wait(#{item.expr.e.str})"
        if item.type=='event'
          printBuffer.add "  -> #{item.event};"
        if item.type=='trigger'
          printBuffer.add "  @(#{item.signal});"
        for statement in item.list
          statementGen(printBuffer,statement)
    printBuffer.add "end"
    printBuffer.blank()

  printBuffer.blank('//register update logic') if inst.__alwaysList.length>0
  for [assignList,lineno] in inst.__alwaysList when assignList? and assignList.length>0
    if lineno? and lineno>=0
      if config.noAlwaysComb
        printBuffer.add 'always @* begin'+"#{lineComment(lineno)}"
      else
        printBuffer.add 'always_comb begin'+"#{lineComment(lineno)}"
    else
      if config.noAlwaysComb
        printBuffer.add 'always @* begin'
      else
        printBuffer.add 'always_comb begin'
    updateEls=[]
    for statement in assignList
      stateType=statement[0]
      if stateType=='assign'
        updateEls.push statement[1]
    for i in _.uniqBy(updateEls,(n)=>n.hier)
      if i.constructor?.name is 'Reg'
        printBuffer.add "  #{global.getPrefix()}_"+i.getName()+'='+getValue(i.getPending())+';'
      else if (i.constructor?.name is 'Wire') or (i.constructor?.name is 'Port')
        printBuffer.add '  '+i.getName()+'='+getValue(i.getPending())+';'
    if assignList
      cond_stack=[]
      for statement in assignList
        statementGen(printBuffer,statement,cond_stack,driven_list)
    printBuffer.add 'end'
    printBuffer.blank()

  printBuffer.blank('//cell instance')
  for i in getCellList(inst)
    paramDeclare=getVerilogParameter(i.inst)
    printBuffer.add i.inst._getModuleName()+paramDeclare+blur(i.name)+'('
    if (not i.inst.__isCombModule)
      if i.inst.__defaultClock
        clockPort=i.inst.__ports[i.inst.__defaultClock]
        if (!clockPort.isBinded())
          clockPort.setBindSignal(inst.__defaultClock)
      if i.inst.__defaultReset
        resetPort=i.inst.__ports[i.inst.__defaultReset]
        if (!resetPort.isBinded())
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

    defaultClk = _.get(inst.__ports,inst._clock())
    defaultRst = _.get(inst.__ports,inst._reset())
    for {pin,port} in i.inst.__pinPortPair when port.getType()=='input'
      item = _.find(driven_list,{key:pin.getId()})
      if not item?
        if port.isClock
          printBuffer.add "assign #{toSignal(pin.getName())} = #{inst.__defaultClock};"
          driven_list.push({key:pin.getElId(),checkPoint:false,inst:pin,driven:[defaultClk.getId()],conds:[]})
        if port.isReset
          printBuffer.add "assign #{toSignal(pin.getName())} = #{inst.__defaultReset};"
          driven_list.push({key:pin.getElId(),checkPoint:false,inst:pin,driven:[defaultRst.getId()],conds:[]})
    printBuffer.blank()

  printBuffer.blank('//Verilog Segment')
  for plainLines in inst.__verilogSegments
    lines=plainLines.split(/\n/)
    for line in lines
      printBuffer.add line
    printBuffer.blank()

  printBuffer.add 'endmodule'
  if global.getIfdefProtect()
    printBuffer.add '`endif'
  printBuffer.blank()
  printBuffer.flush()
  return sig_driven_tree

getVerilogParameter=(inst)->
  if inst.__instParameter==null
    return ' '
  else
    list=[]
    for i in inst.__instParameter
      list.push(".#{i.key}(#{i.value})")
    return " #(\n  "+list.join(",\n  ")+"\n) "

module.exports.buildCompanyModule=(companyModule,params...)->
  inst=new companyModule(params...)
  inst._setCompany()
  name=inst._getModuleName() ? inst.constructor.name
  if not globalModuleCache[name]?
    globalModuleCache[name]=inst
    toVerilog(inst)
  return globalModuleCache[name]

module.exports.buildGlobalModule=(globalModule,params...)->
  inst=new globalModule(params...)
  inst._setGlobal()
  name=inst._getModuleName() ? inst.constructor.name
  if not globalModuleCache[name]?
    globalModuleCache[name]=inst
    toVerilog(inst)
  return globalModuleCache[name]

toVerilog=(inst)->
  cell_build(inst)
  instList=[]
  inst_sig_driven=code_gen(inst,instList,true)
  if global.isCdcCheck()
    clkGroup=buildClkTree(inst_sig_driven)
    cdcResult=cdcAnalysis(inst_sig_driven,clkGroup)
    reportFile=global.getCdcReportFile()
    if reportFile?
      outFile=global.getOutDir()+'/'+reportFile
      fs.writeFileSync(outFile,JSON.stringify(cdcResult,null,'  '),'utf8')

  if config.tree
    console.log(stringifyTree({name:inst._getModuleName(),inst:inst}, ((t) -> t.name+' ('+t.inst._getModuleName()+')'), ((t) -> getCellList(t.inst))))
  if global.getInfo()
    list=    [['register name','width']]
    list.push(['-------------','-----'])
    dffBitSum=0
    for [name,reg] in toFlatten(inst.__regs)
      list.push([toSignal(name),reg.getWidth()])
      dffBitSum+=reg.getWidth()
    for [name,reg] in toFlatten(inst.__local_regs)
      list.push([reg.refName(),reg.getWidth()])
      dffBitSum+=reg.getWidth()
    if list.length>2
      list.push(['-------------','-----'])
      list.push(['TotalBits',dffBitSum])
      console.log(table(list,{singleLine:true,columnDefault: {width:30}}))
  if global.getInfo()
    condCnt=0
    transferCnt=0
    tableList=[]
    tableList.push(['Module','Condition','Transfer'])
    for i in instList
      condCnt+=i.__lint._cnt.cond
      transferCnt+=i.__lint._cnt.transfer
      tableList.push([i._getModuleName(),i.__lint._cnt.cond,i.__lint._cnt.transfer])
    tableList.push(['----------','-----','-----'])
    tableList.push(['Summary',condCnt,transferCnt])
    console.log(table(tableList,{singleLine:true,columnDefault: {width:30}}))
  return inst

input=(width=1)->packEl('port',Port.in(width))

output=(width=1)->packEl('port',Port.out(width))

bind= (name)-> Port.bind(name)

channel= (path=null)-> Channel.create(path)

instEnv= do ->
  inst=null
  return {
    register: (i)-> inst=i
    infer: ()-> inst.__assignWidth
    get: -> inst
  }

cntCond=(num)->
  if global.getInfo()
    instEnv.get().__lint._cnt.cond+=num

cntExpr= ->
  if global.getInfo()
    instEnv.get().__lint._cnt.transfer+=1

getLint= (key)->
  if instEnv.get().__lint[key]?
    return instEnv.get().__lint[key]
  else
    return null


module.exports.hex = Vnumber.hex
module.exports.dec = Vnumber.dec
module.exports.oct = Vnumber.oct
module.exports.bin = Vnumber.bin

module.exports.Module    = Module
module.exports.Expr      = Expr
module.exports.toVerilog   = toVerilog
module.exports.input       = input
module.exports.output      = output
module.exports.bind        = bind
module.exports.channel     = channel
module.exports.infer        = instEnv.infer
module.exports.configBase =(cfg)-> config=Object.assign(config,cfg)
module.exports.resetBase   = ->
  moduleCache={}
  globalModuleCache={}
  moduleIndex=0
