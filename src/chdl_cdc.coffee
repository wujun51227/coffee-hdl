{toSignal,toFlatten,syncType} = require 'chdl_utils'
log     = require 'fancy-log'
global  = require 'chdl_global'
{table} = require 'table'
_       = require 'lodash'

cdcError=[]

getSyncId=(el)->
  sync = el.getSync()
  return null unless sync?
  cell = el.getCell()
  id = null
  if sync.value?
    id = _.get(cell,sync.value).getId()
  return {
    type: sync.type
    id: id
  }

getClkGroup=(key,group)->
  for k,v of group when v[key]
    return k
  return null

traceClock=(id,sigDrivenList,clkGroup)->
  el = global.queryId(id)
  unless el?
    throw new Error('can not query global id '+id)
  if el.isClock
    ret=getClkGroup(id,clkGroup)
    return ret if ret?

  for i in sigDrivenList when i.key==id
    driveKey=i.driven[0]
    ret=traceClock(driveKey,sigDrivenList,clkGroup)
    if ret?
      clkGroup[ret][id]=1
      return ret
    else
      throw new Error('can not find clock group '+el.getName())
  return null

getKeyByName=(name,list)->
  for i in list
    if i.obj.getName()==name
      return i.key
   throw new Error('can not find key by name '+name)

buildClkTree=(driven_tree,clkGroup={},first=true)->
  inst=driven_tree.inst
  if inst.__parentNode==null
    for [name,port] in toFlatten(inst.__ports) when port.isClock
      clkGroup[port.getName()]={[port.getId()]:1}

  for [name,channel] in toFlatten(inst.__channels)
    if channel.constructor.name=='Channel'
      portList=channel.getPortList()
    else if channel.constructor.name=='Wire'
      portList=channel.bindChannel.getPortList()
    else
      throw new Error("Can not get portList from ",channel.constructor.name)
    for i in portList when i.port.isClock
      #console.log "find clock",i.port.getName()
      pinKey = getKeyByName(i.pin,driven_tree.list)
      ret=traceClock(pinKey,driven_tree.list,clkGroup)
      #console.log "check 2",i.port.getId(),i.port.getName(),ret
      if ret?
        clkGroup[ret][i.port.getId()]=1

  for i in driven_tree.children when !i.inst.__isCombModule
    for [name,port] in toFlatten(i.inst.__ports) when port.isClock and port.bindSignal?
      portKey=port.getId()
      ret=getClkGroup(portKey,clkGroup)
      if not ret?
        pinKey = _.get(inst,port.bindSignal).getId()
        ret=traceClock(pinKey,driven_tree.list,clkGroup)
        if ret?
          #xxx= _.get(inst,port.bindSignal)
          #console.log "check 1",port.getId(),xxx.getName(),ret,port.bindSignal
          clkGroup[ret][port.getId()]=1
        else
          throw new Error("can not find clock group of "+port.bindSignal)


  for i in driven_tree.children
    buildClkTree(i,clkGroup,false)

  #console.log clkGroup
  if first
    log "Clock Group Report".yellow
    data=[]
    for clkName,ids of clkGroup
      for id,index in Object.keys(ids)
        inst=global.queryId(id)
        if index==0
          data.push([clkName,inst.getPath().join(".")])
        else
          data.push(["",inst.getPath().join(".")])
    console.log table(data,{singleLine:true})
  return clkGroup

isSameClkGroup=(a,b,clkGroup)->
  if not a?
    throw new Error("a id is null")

  if not b?
    throw new Error("b id is null")

  aGroup=null
  bGroup=null
  for k,v of clkGroup
    if v[a]==1
      aGroup=k
    if v[b]==1
      bGroup=k

    if aGroup? and bGroup?
      return aGroup==bGroup
  return false

markSync=(sig,driveSig,syncObj,clkGroup)->
  if not sig.sync?
    sig.sync = _.clone(syncObj)
    #console.log "markSync",sig.obj.getName(),syncObj
    return true
  else
    if sig.sync.type==syncType.async
      return true
    else if sig.sync.type==syncType.ignore
      return true
    else if sig.sync.type==syncType.stable
      return true
    else if sig.sync.type==syncType.sync || sig.sync.type==syncType.capture
      if syncObj.type==syncType.sync || syncObj.type==syncType.ignore
        if not isSameClkGroup(sig.sync.id,syncObj.id,clkGroup)
          cdcError.push({
            msg:"clock crossing",
            targetSig:sig.obj.getPath(),
            targetClk:getClkGroup(sig.sync.id,clkGroup) ? ''
            sourceSig:driveSig
            sourceClk:getClkGroup(syncObj.id,clkGroup) ? ''
          })
          return false
        else
          return true
      else if syncObj.type==syncType.async
        cdcError.push({
          msg:"async signal latch",
          targetSig:sig.obj.getPath()
          targetClk:getClkGroup(sig.sync.id,clkGroup) ? ''
          sourceSig:driveSig
          sourceClk:getClkGroup(syncObj.id,clkGroup) ? ''
        })
        return false
      else if syncObj.type==syncType.stable || syncObj.type==syncType.capture
        return true
      else if syncObj==null
        console.log "Error: drive signal sync obj is null",driveSig
        return false

findDriveWire=(sig,list)->
  ret=[]
  if sig.getLsb()==-1
    ret = _.filter(list,(i)=>i.obj.getName()==sig.getName())
  else
    for i in list
      if i.obj.getName()==sig.getName()
        msb = i.obj.getMsb()
        lsb = i.obj.getLsb()
        if lsb==-1
          ret.push(i)
        else if not(sig.getLsb()>msb or sig.getMsb()<lsb)
          ret.push(i)
  #console.log ret
  return ret

cdcReport= ->
  if cdcError.length>0
    console.log "CDC Issue Found !!!".red
    data=[]
    for i in cdcError
      data.push(["Type",i.msg])
      data.push(["Target",i.targetSig.join(".")+'('+i.targetClk+')'])
      data.push(["Source",i.sourceSig.join(".")+'('+i.sourceClk+')'])
    console.log table(data,{
      drawHorizontalLine: (lineIndex, rowCount) =>
          return lineIndex%3 == 0
    })
  else
    console.log "CDC Pass!!!".green
  cdcError=[]

cdcCheck=(driveObj,list,clkGroup)->
  #console.log 'check obj',driveObj.obj.getName(),driveObj.driven,driveObj.sync
  for id in driveObj.driven
    el=global.queryId(id)
    elType=el.constructor.name
    if elType=='Reg'
      ret=markSync(driveObj,el.getPath(),getSyncId(el),clkGroup)
    else if elType=='Port' and el.getType()=='input'
      if el.isClock
        ret=getClkGroup(el.getId(),clkGroup)
      else
        syncObj = getSyncId(el)
        if syncObj==null
          driveWireList=findDriveWire(el,list)
          for driveWire in driveWireList
            unless driveWire.sync?
              cdcCheck(driveWire,list,clkGroup)
            if driveWire.sync? #net maybe connect a const value
              ret=markSync(driveObj,driveWire.obj.getPath(),driveWire.sync,clkGroup)
        else
          ret=markSync(driveObj,el.getPath(),getSyncId(el),clkGroup)
    else
      if el.getSync()?
        ret=markSync(driveObj,el.getPath(),getSyncId(el),clkGroup)
      else
        driveWireList=findDriveWire(el,list)
        for driveWire in driveWireList
          #console.log driveWire
          #console.log driveWire.key,driveWire.sync,driveWire.obj.refName()
          unless driveWire.sync?
            cdcCheck(driveWire,list,clkGroup)
          if driveWire.sync? #net maybe connect a const value
            ret=markSync(driveObj,driveWire.obj.getPath(),driveWire.sync,clkGroup)

  for id in _.flatten(driveObj.conds)
    condWire=global.queryId(id)
    condType=condWire.constructor.name
    #console.log 'cond',condWire.getSync(),condType,condWire.getType()
    if condType=='Reg'
      ret=markSync(driveObj,condWire.getPath(),getSyncId(condWire),clkGroup)
    else if condType=='Port' and condWire.getType()=='input'
      ret=markSync(driveObj,condWire.getPath(),getSyncId(condWire),clkGroup)
    else
      driveWireList=findDriveWire(condWire,list)
      for driveWire in driveWireList
        unless driveWire.sync?
          cdcCheck(driveWire,list,clkGroup)
        if driveWire.sync? #net maybe connect a const value
          ret=markSync(driveObj,driveWire.obj.getPath(),driveWire.sync,clkGroup)

cdcAnalysis=(driven_tree,clkGroup,first=true)->

  channelPortList=[]
  for i in driven_tree.children
    for pair in i.inst.__pinPortPair
      channelPortList.push(pair)
    if i.inst.__isCombModule
      driven_tree.list.push(i.list...)
    else
      cdcAnalysis(i,clkGroup,false)

  log ("Clock Domain Crossing Checking, Module: "+driven_tree.inst.getModuleName()).yellow

  for {pin,port} in channelPortList
    instPort= port
    wireObj = pin
    if instPort.getType()=='output'
      driven_tree.list.push(
        {key:wireObj.getId(),checkPoint:false,obj:wireObj,driven:[instPort.getId()],conds:[]}
      )
    else if instPort.getType()=='input'
      if instPort.getCell().__isCombModule
        driven_tree.list.push(
          {key:instPort.getId(),checkPoint:false,obj:instPort,driven:[wireObj.getId()],conds:[]}
        )
      else
        #console.log '>>>>',wireObj.getName(),item.pin
        if !instPort.isClock
          driven_tree.list.push(
            {key:instPort.getId(),checkPoint:true,obj:instPort,driven:[wireObj.getId()],conds:[]}
          )

  wireList=(i for i in driven_tree.list when !i.checkPoint)
  for i in wireList
    cdcCheck(i,driven_tree.list,clkGroup)

  syncList=(i for i in driven_tree.list when i.checkPoint)
  for i in syncList
    if i.obj.constructor.name=='Reg'
      #log "check reg:",i.obj.getName()
      i.sync=getSyncId(i.obj)
    else if i.obj.constructor.name=='Wire'
      i.sync=getSyncId(i.obj)
    else if i.obj.constructor.name=='Port'
      if i.obj.getType()=='output'
        if i.obj.isReg
          #log "check output reg:",i.obj.getName()
          i.sync=getSyncId(i.obj.shadowReg)
        else
          #log "check output port:",i.obj.getName()
          i.sync=getSyncId(i.obj)
      else if i.obj.getType()=='input'
        i.sync=getSyncId(i.obj)
        #throw new Error("Can not check input port "+ i.obj.getName())
    else
      throw new Error("unknown type "+i.obj.constructor.name)
    if not i.obj.isClock
      #console.log "checking",i.obj.getName()
      cdcCheck(i,driven_tree.list,clkGroup)
  cdcReport()

module.exports.buildClkTree = buildClkTree
module.exports.cdcAnalysis  = cdcAnalysis
