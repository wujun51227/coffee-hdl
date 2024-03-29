{toSignal,toFlatten,syncType} = require 'chdl_utils'
log     = require 'fancy-log'
global  = require 'chdl_global'
{table} = require 'table'
_       = require 'lodash'

cdcError=[]

getSyncObj=(el)->
  if el.isClock
    return {
      type: syncType.sync
      id: el.getId()
    }
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

findSync=(sig,list)->
  elSync=sig.getSync()
  if elSync?
    return elSync
  else
    ret = findDriveCheckObjs(sig,list)
    if ret.length==1
      driveInst=global.queryId(ret[0].driven[0])
      return findSync(driveInst,list)
    else
      throw new Error("sync is not uniq "+ret)

traceClock=(el,drivenList,clkGroup,genClkList)->
  id = el.getId()
  elId = el.getElId()
  unless el?
    throw new Error('can not query global id '+id)
  if el.isClock
    ret=getClkGroup(id,clkGroup)
    return ret if ret?
  genClkObj=_.find(genClkList,{genClkId:id})
  if genClkObj?
    genClk = global.queryId(genClkObj.clkId)
    ret=traceClock(genClk,drivenList,clkGroup,genClkList)
    if ret?
      clkGroup[ret][id]=1
      return ret
    else
      throw new Error("trace gen clock failed "+genClkObj.clkId)

  driveClkObj=_.find(drivenList,{key:elId})
  if driveClkObj?
    driveInst= global.queryId(driveClkObj.driven[0])
    ret=traceClock(driveInst,drivenList,clkGroup,genClkList)
    if ret?
      clkGroup[ret][id]=1
      return ret
    else
      elSync= findSync(el,drivenList)
      if elSync.syncType==syncType.sync
        ret=getClkGroup(id,clkGroup)
        return ret if ret?
      throw new Error('can not find clock group '+el.getName())

  return null

getKeyByName=(name,list)->
  for i in list
    if i.inst.getName()==name
      return i.key
   throw new Error('can not find key by name '+name)

buildClkTree=(driven_tree,clkGroup={},first=true)->
  inst=driven_tree.inst
  if inst.__parentNode==null
    for [name,port] in toFlatten(inst.__ports) when port.isClock
      clkGroup[port.getName()]={[port.getElId()]:1} # find root clock

  subModuleClkList=[]
  generateClockList=[]
  for i in driven_tree.children
    for pair in i.inst.__pinPortPair
      instPort= pair.port
      wireObj = pair.pin
      if instPort.getType()=='output' and instPort.isGenerateClock
        syncInfo = instPort.getSync()
        clkInst=instPort.getCell().__ports[syncInfo.value]
        generateClockList.push(
          {genClkId: instPort.getElId(), clkId: clkInst.getElId()}
        )
        subModuleClkList.push(
          {key:wireObj.getElId(),checkPoint:false,inst:wireObj,driven:[instPort.getId()],conds:[]}
        )
      if instPort.getType()=='input'  and instPort.isClock
        subModuleClkList.push(
          {key:instPort.getElId(),checkPoint:false,inst:instPort,driven:[wireObj.getId()],conds:[]}
        )

  driven_list=[driven_tree.list...,subModuleClkList...]

  for i in driven_tree.children # scan all module's clock input
    for pair in i.inst.__pinPortPair
      instPort= pair.port
      wireObj = pair.pin
      if instPort.isClock
        ret=traceClock(wireObj,driven_list,clkGroup,generateClockList)  # trace module clock to root clock or generate clock
        if ret?
          clkGroup[ret][instPort.getElId()]=1
        else
          global.dumpId()
          throw new Error("trace clock failed "+wireObj.getPath()+' '+wireObj.getId())

  for i in driven_tree.children when !i.inst.__isCombModule
    for [name,port] in toFlatten(i.inst.__ports) when port.isClock and port.bindSignal?
      portKey=port.getElId()
      ret=getClkGroup(portKey,clkGroup)
      if not ret?
        pinObj= _.get(inst,port.bindSignal)
        pinId=pinObj.getId()
        pinInst=global.queryId(pinId)
        ret=traceClock(pinInst,driven_list,clkGroup)
        if ret?
          clkGroup[ret][port.getElId()]=1
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

mergeSync=(checkObj,syncObj,clkGroup)->
  if syncObj==null
    throw new Error("Error: drive signal sync inst is null "+checkObj)
  if not checkObj.sync?
    checkObj.sync = _.clone(syncObj)
    if checkObj.sync.type==syncType.trans
      checkObj.sync.type=syncType.sync
      checkObj.sync.dirty=true
    #console.log "mergeSync",checkObj.inst.getName(),syncObj
  else
    if checkObj.sync.type==syncType.sync || checkObj.sync.type==syncType.capture ||checkObj.sync.type==syncType.unstable
      if syncObj.type==syncType.sync || syncObj.type==syncType.trans
        if not isSameClkGroup(checkObj.sync.id,syncObj.id,clkGroup)
          checkObj.sync.type = syncType.async
          #console.log "mergeSync as async",checkObj.inst.getName(),syncObj
        else
          if syncObj.type==syncType.trans
            if checkObj.sync.dirty==true
              checkObj.sync.type = syncType.async
            else
              checkObj.sync.dirty=true
          else if syncObj.type==syncType.sync and syncObj.dirty==true
            checkObj.sync.dirty=true
      else if syncObj.type==syncType.async || syncObj.type==syncType.unstable
        checkObj.sync.type = syncType.async
        #console.log "mergeSync as async",checkObj.inst.getName(),syncObj

syncJudge=(checkObj,driveSigPath,syncObj,clkGroup)->
  if syncObj==null
    console.log "Error: drive signal sync inst is null",driveSigPath
    return false
  if not checkObj.sync?
    checkObj.sync = _.clone(syncObj)
    if checkObj.sync.type==syncType.trans
      checkObj.sync.type=syncType.sync
      checkObj.sync.dirty=true
    #console.log "markSync",checkObj.inst.getName(),syncObj
  else
    if checkObj.sync.type==syncType.sync || checkObj.sync.type==syncType.capture ||checkObj.sync.type==syncType.unstable
      if syncObj.type==syncType.sync || syncObj.type==syncType.trans
        if not isSameClkGroup(checkObj.sync.id,syncObj.id,clkGroup)
          cdcError.push({
            msg:"clock crossing",
            targetSig:checkObj.inst.getPath(),
            targetClk:getClkGroup(checkObj.sync.id,clkGroup) ? ''
            sourceSig:driveSigPath
            sourceClk:getClkGroup(syncObj.id,clkGroup) ? ''
          })
        else
          if syncObj.type==syncType.trans
            if checkObj.sync.dirty==true
              cdcError.push({
                msg:"async converge",
                targetSig:checkObj.inst.getPath(),
                targetClk:getClkGroup(checkObj.sync.id,clkGroup) ? ''
                sourceSig:driveSigPath
                sourceClk:getClkGroup(syncObj.id,clkGroup) ? ''
              })
            else
              checkObj.sync.dirty=true
          else if syncObj.type==syncType.sync and syncObj.dirty==true
            if checkObj.sync.dirty==true
              cdcError.push({
                msg:"async converge",
                targetSig:checkObj.inst.getPath(),
                targetClk:getClkGroup(checkObj.sync.id,clkGroup) ? ''
                sourceSig:driveSigPath
                sourceClk:getClkGroup(syncObj.id,clkGroup) ? ''
              })
              checkObj.sync.type = syncType.async
            else
              checkObj.sync.dirty=true
      else if syncObj.type==syncType.async || syncObj.type==syncType.unstable
        cdcError.push({
          msg:"async signal latch",
          targetSig:checkObj.inst.getPath()
          targetClk:getClkGroup(checkObj.sync.id,clkGroup) ? ''
          sourceSig:driveSigPath
          sourceClk:getClkGroup(syncObj.id,clkGroup) ? ''
        })

findDriveCheckObjs=(el,list)->
  ret=[]
  if el.getLsb()==-1
    ret = _.filter(list,(i)=>i.key==el.getElId())
  else
    for i in list
      if i.key==el.getElId()
        msb = i.inst.getMsb()
        lsb = i.inst.getLsb()
        if lsb==-1
          ret.push(i)
        else if not(el.getLsb()>msb or el.getMsb()<lsb)
          ret.push(i)
  #console.log ret
  return ret

cdcReport= ->
  if cdcError.length>0
    console.log "CDC Issue Found".red
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
    console.log "CDC Pass".green
  cdcError=[]

traceWireSync=(checkObj,driveEl,list,clkGroup)->
  #console.log ">>>",checkObj.inst.getPath(),driveEl.getPath()
  if driveEl.isClock or driveEl.getSync()?
    mergeSync(checkObj,getSyncObj(driveEl),clkGroup)
  else
    driveCheckObjs=findDriveCheckObjs(driveEl,list)
    if driveCheckObjs.length==0
      throw new Error("can not find drive items "+driveEl.getPath())
    for item in driveCheckObjs
      unless item.sync?
        cdcWireMark(item,list,clkGroup)
      if item.sync? #net maybe connect a const value
        mergeSync(checkObj,item.sync,clkGroup)
      else
        throw new Error("can not mark wire sync "+checkObj.inst.getPath()+item.inst.getPath())

cdcWireMark=(checkObj,list,clkGroup)->
  #console.log 'wire mark',checkObj.inst.getPath(),checkObj.driven,checkObj.sync
  if checkObj.driven.length==0 and checkObj.conds.length==0
    mergeSync(checkObj,{type:syncType.stable},clkGroup)

  for id in checkObj.driven
    el=global.queryId(id)
    traceWireSync(checkObj,el,list,clkGroup)

  for id in _.flatten(checkObj.conds)
    el=global.queryId(id)
    traceWireSync(checkObj,el,list,clkGroup)
  #console.log "--end wire mark"

syncCheck=(checkObj,el,list,clkGroup)->
  if el.isClock or el.getSync()?
    syncJudge(checkObj,el.getPath(),getSyncObj(el),clkGroup)
  else
    driveWireList=findDriveCheckObjs(el,list)
    for driveWire in driveWireList
      unless driveWire.sync?
        cdcWireMark(driveWire,list,clkGroup)
      if driveWire.sync? #net maybe connect a const value
        syncJudge(checkObj,driveWire.inst.getPath(),driveWire.sync,clkGroup)
      else
        throw new Error("can not check sync")

cdcCheck=(checkObj,list,clkGroup)->
  #console.log 'check',checkObj.inst.getPath(),checkObj.driven,checkObj.sync
  for id in checkObj.driven
    el=global.queryId(id)
    syncCheck(checkObj,el,list,clkGroup)

  for id in _.flatten(checkObj.conds)
    condWire=global.queryId(id)
    #console.log "condition",id
    syncCheck(checkObj,condWire,list,clkGroup)
  #console.log "--end check"

cdcAnalysis=(driven_tree,clkGroup,result=[])->

  channelPortList=[]
  for i in driven_tree.children
    for pair in i.inst.__pinPortPair
      channelPortList.push(pair)
    if i.inst.__isCombModule
      driven_tree.list.push(i.list...)
    else
      cdcAnalysis(i,clkGroup,result)

  log ("Clock Domain Crossing Checking, Module: "+driven_tree.inst._getModuleName()).yellow

  for {pin,port} in channelPortList
    instPort= port
    wireObj = pin
    if instPort.getType()=='output'
      driven_tree.list.push(
        {key:wireObj.getElId(),checkPoint:false,inst:wireObj,driven:[instPort.getId()],conds:[]}
      )
    else if instPort.getType()=='input'
      if instPort.getCell().__isCombModule
        driven_tree.list.push(
          {key:instPort.getElId(),checkPoint:false,inst:instPort,driven:[wireObj.getId()],conds:[]}
        )
      else
        #console.log '>>>>',wireObj.getName(),item.pin
        if !instPort.isClock
          driven_tree.list.push(
            {key:instPort.getElId(),checkPoint:true,inst:instPort,driven:[wireObj.getId()],conds:[]}
          )

  wireList=(i for i in driven_tree.list when !i.checkPoint)
  for i in wireList
    cdcWireMark(i,driven_tree.list,clkGroup)

  syncList=(i for i in driven_tree.list when i.checkPoint)
  for i in syncList
    i.sync=getSyncObj(i.inst)
    if not i.sync?
      throw new Error("can not find checkpoint sync info"+i.inst.getPath())

  for i in syncList when not i.inst.isClock
    #console.log "checking",i.obj.getName()
    cdcCheck(i,driven_tree.list,clkGroup)
  result.push({instance:driven_tree.inst._getPath(),report:cdcError})
  cdcReport()
    
  return result

module.exports.buildClkTree = buildClkTree
module.exports.cdcAnalysis  = cdcAnalysis
