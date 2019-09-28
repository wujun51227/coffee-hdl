Port    = require 'chdl_port'
Expr    = require 'chdl_expr'
Reg     = require 'chdl_reg'
Wire    = require 'chdl_wire'
Channel = require 'chdl_channel'
ElementSets = require 'chdl_el_sets'
{table} = require 'table'
{packEl,toSignal,toFlatten}=require('chdl_utils')
_ = require 'lodash'
log    =  require 'fancy-log'
uuid  = require 'uuid/v1'

localCnt=0

_id=(name)=>
  ret="#{name}#{localCnt}"
  localCnt+=1
  return ret

class Module
  @create: (args...)-> new this(args...)

  _mixin: (obj) ->
    for fname in _.functions obj
      if fname.match(/^\$/)
        m=fname.match(/^\$(.*)/)
        @['_'+m[1]] = obj[fname]
      else
        @[fname] = obj[fname]

  _mixinas: (name,obj) ->
    @[name]={}
    for fname in _.functions obj
      @[name][fname] = (args...)=>obj[fname].call(this,args...)

  __instName: ''

  __config:{}

  __signature:{}

  _cellmap: (v) ->
    for name,inst of v
      @__cells.push({name:name,inst:inst})

  __getCell: (name)=>
    p=Object.getPrototypeOf(this)
    for k,v of p when typeof(v)=='object' and v instanceof Module
      return v if k==name
    return _.find(@__cells,{name:name})

  __setConfig: (v) -> @__config=v

  _reg: (obj) ->
    for k,v of obj
      @__regs[k]=v
      if this[k]?
        throw new Error('Register name conflicted '+k)
      else
        this[k]=v
        for [name,inst] in toFlatten(v)
          inst.link(this,toSignal(k+'.'+name))

  _wire: (obj) ->
    for k,v of obj
      @__wires[k]=v
      if this[k]?
        throw new Error('Wire name conflicted '+k)
      else
        this[k]=v
        for [name,inst] in toFlatten(v)
          inst.link(this,toSignal(k+'.'+name))

  _mem: (obj) ->
    for k,v of obj
      @__vecs[k]=v
      if this[k]?
        throw new Error('Vec name conflicted '+k)
      else
        this[k]=v
        for [name,inst] in toFlatten(v)
          inst.link(this,toSignal(k+'.'+name))

  _channel: (obj) ->
    for k,v of obj
      @__channels[k]=v
      if this[k]?
        throw new Error('Channel name conflicted '+k)
      else
        for [name,inst] in toFlatten(v)
          inst.link(this,toSignal(k+'.'+name))
        this[k]=v

  _probe: (obj) ->
    for k,v of obj
      @__channels[k]=Channel.create(v)
      #if this[k]?
      #  throw new Error('Channel name conflicted '+k)
      #else
      #  this[k]=@__channels[k]

  _port: (obj) ->
    for k,v of obj
      @__ports[k]=v
      @__wires[k]=v
      if this[k]?
        throw new Error('Port name conflicted '+k)
      else
        this[k]=v
        for [name,inst] in toFlatten(v)
          sigName=toSignal(k+'.'+name)
          inst.link(this,sigName)
          if inst.isClock
            @__setDefaultClock(sigName)
          if inst.isReset
            @__setDefaultReset(sigName)
          if inst.isReg
            createReg=new Reg(inst.getWidth())
            createReg.config(inst.isRegConfig)
            @__regs[sigName]=createReg
            createReg.link(this,sigName)

  __overrideModuleName: (name)-> @__moduleName=name
  getModuleName: -> @__moduleName
  setCombModule: -> @__isCombModule=true
  specifyModuleName: (name)->
    @__specifyModuleName=name
    @__specify=true

  instParameter: (s)->  @__instParameter=s

  moduleParameter: (s)->  @__moduleParameter=s

  constructor: (param=null)->
    @param=param
    @__id = uuid()
    #@moduleName=this.constructor.name
    @__moduleName=null
    @__isCombModule=false
    @__instParameter=null
    @__moduleParameter=null

    @__alwaysList     =  []
    @__sequenceAlwaysList     =  []
    @__pureAlwaysList     =  []
    @__regs           =  {}
    @__wires          =  {}
    @__local_wires      =  []
    @__local_regs      =  []
    @__vecs           =  {}
    @__channels       =  {}
    @__ports          =  {}
    @__wireAssignList =  []
    @__initialList=[]
    @__sequenceBlock=null
    @__cells      =[]

    @__bindChannels=[]
    @__defaultClock=null
    @__defaultReset=null

    @__regAssignList=[]
    @__sequenceAssignList=[]
    @__trigMap={}
    @__assignWidth=null
    @__updateWires=[]
    @__assignWaiting=false
    @__assignInAlways=false
    @__assignInSequence=false
    @__parentNode=null
    @__indent=0
    @__postProcess=[]
    @__isBlackBox=false
    @__specify=false
    @__specifyModuleName=null
    @__autoClock=true
    @__pinAssign=[]
    @_mixin require('chdl_primitive_lib.chdl.js')

  __setParentNode: (node)->
    @__parentNode=node

  __setDefaultClock: (clock)->
    @__defaultClock=clock if @__defaultClock==null

  __setDefaultReset: (reset)->
    @__defaultReset=reset if @__defaultReset==null

  setDefaultClock: (clock)=>
    @__defaultClock=clock

  setDefaultReset: (reset)=>
    @__defaultReset=reset

  setBlackBox: ()=> @__isBlackBox=true

  isBlackBox: ()=> @__isBlackBox

  disableAutoClock: ()=> @__autoClock=false

  _getChannelWire: (channelName,path=null)->
    if @__channels[channelName]?
      return @__channels[channelName].getWire(path)
    else
      console.error 'Channel',channelName,'not found'
      console.trace()

  __dumpPorts: ->
    console.log 'Module',@__instName
    for [name,port] in toFlatten(@__ports)
      s=toSignal(port.getName())
      console.log '  port',s

  __addWire: (name,width)->
    wire= Wire.create(width)
    wire.link(this,name)
    pack=packEl('wire',wire)
    @__wires[name]=pack
    this[name]=pack
    return wire

  __addPort: (name,dir,width)->
    port=do ->
      if dir=='input'
        Port.in(width)
      else if dir=='output'
        Port.out(width)
      else
        throw new Error('unkown dir '+dir)
    if this[name]?
      console.trace()
      console.log "Port #{name} has been defined"
      return null
    else
      port.link(this,name)
      @__ports[name]=port
      @__wires[name]=port
      return port

  __dragPort: (inst,dir,width,pathList,portName)->
    nextInst=_.get(inst,pathList[0])
    if nextInst? and nextInst instanceof Module
      newPortName=toSignal([pathList[1..]...,portName].join('.'))
      port=nextInst.__addPort(newPortName,dir,width)
      if port?
        port.setBindSignal(toSignal([pathList...,portName].join('.')))
        #nextInst.addWire(newPortName,width)
        #nextInst.dumpPorts()
        @__dragPort(nextInst,dir,width,pathList[1..],portName)

  __removeNode:(list)->
    if list.length==1
      leaf=list[0]
      delete this[leaf]
      delete @__ports[leaf]
      delete @__wires[leaf]
    else if list.length>1
      plist=list.slice(0,list.length-1)
      leaf=_.last(list)
      node=_.get(this,plist)
      delete node[leaf]
      delete @__ports[leaf]
      delete @__wires[leaf]

  __findChannel: (inst,list)->
    if _.get(inst,list)?
      return _.get(inst,list)

    if list.length==1
      out=inst.__channels[list[0]]
      return out
    else
      nextInst=inst[list[0]]
      return @__findChannel(nextInst,list.slice(1))

  __channelExpand:(channelType,localName,channelInfo)->
    localport=null
    nodeList=[]
    if channelType=='hub'
      nodeList=_.toPath(localName)
    else
      for [name,port] in toFlatten(@__ports)
        if toSignal(name)==localName
          localport=port
          nodeList=_.toPath(name)
      for [name,port] in toFlatten(@__channels)
        if toSignal(name)==localName
          localport=port
          nodeList=_.toPath(name)
      for [name,port] in toFlatten(@__wires)
        if toSignal(name)==localName
          localport=port
          nodeList=_.toPath(name)

    type=null
    if localport?
      type=localport.constructor.name
      if localport?.width==0
        @__removeNode(nodeList) if channelType!='hub'

    if _.isString(channelInfo)
      channel=@__findChannel(this,_.toPath(channelInfo))
      channelName=channelInfo
    else
      channel=channelInfo
      channelName=channelInfo.getName()
    for obj in channel.portList
      bindPort=obj.port
      dir=bindPort.type
      width=bindPort.width
      @__dragPort(this,dir,width,_.toPath(channelName),obj.node.join('.'))
      if dir=='output' or dir=='input'
        wireName=toSignal([channelName,obj.node...].join('.'))
        wire=@__addWire(wireName,width)
        newPath=[nodeList...,obj.node...].join('.')
        if type=='Port'
          net=new Port(dir,width)
          net.link(this,toSignal(newPath))
          netEl=packEl('port',net)
          #log 'set port',newPath,obj.path
          if _.get(this,newPath)?
            throw new Error "Error: #{newPath} is conflict"
          _.set(this,newPath,netEl)
          _.set(@__ports,newPath,netEl)
          _.set(@__wires,newPath,netEl)
        else
          if not _.get(this,newPath)?
            net=Wire.create(width)
            net.link(this,toSignal(newPath))
            netEl=packEl('wire',net)
            _.set(this,newPath,netEl)
            _.set(@__wires,newPath,netEl)
          else
            net=_.get(this,newPath)
        if dir=='input'
          if type=='Wire'
            wire.assign(->toSignal(net.getName()))
            @__pinAssign.push({
              from: toSignal(net.getName())
              to: wireName
            })
          else
            wire.assign(->toSignal(newPath))
            @__pinAssign.push({
              from: toSignal(newPath)
              to: wireName
            })
        else if dir=='output'
          net.assign(->wire.getName())
          @__pinAssign.push({
            from: toSignal(wire.getName())
            to: net.getName()
          })

    for i in @__bindChannels
      i.channel.portList.length=0
      i.channel.bindPort(this,i.portName)

  __postElaboration: ->
    for i in @__postProcess
      @__channelExpand(i.type,i.elName,i.bindChannel)

  __elaboration: ->
    if @__config.info
      console.log('Name:',@__instName,@constructor.name)
    list=    [['Port name','dir'  ,'width']]
    list.push(['---------','-----','-----'])
    for [name,port] in toFlatten(@__ports)
      if port.type==null
        @__postProcess.push {type:'port',elName:port.getName(),bindChannel:port.bindChannel}
      else
        list.push([toSignal(name),port.getType(),port.getWidth()])
    if list.length>2 and @__config.info
      console.log(table(list,{singleLine:true,columnDefault: {width:30}}))
    list=    [['register name','width']]
    list.push(['-------------','-----'])
    for [name,reg] in toFlatten(@__regs)
      list.push([toSignal(name),reg.getWidth()])
    if list.length>2 and @__config.info
      console.log(table(list,{singleLine:true,columnDefault: {width:30}}))
    for [name,channel] in toFlatten(@__channels)
      if channel.probeChannel?  # probe dont have elName
        @__postProcess.push {type:'channel',elName:name,bindChannel:channel.probeChannel}

    for i in @__bindChannels
      #log 'elaboration bind',this.constructor.name,i.portName
      i.channel.bindPort(this,i.portName)

  _always: (block)=>
    @__assignInAlways=true
    @__regAssignList=[]
    @__updateWires=[]
    block()
    @__alwaysList.push([@__regAssignList,@__updateWires])
    @__assignInAlways=false
    @__updateWires=[]
    @__regAssignList=[]

  _passAlways: (block)=>
    @__assignInAlways=true
    @__regAssignList=[]
    @__updateWires=[]
    block()
    @__alwaysList.push([@__regAssignList,[]])
    @__assignInAlways=false
    @__updateWires=[]
    @__regAssignList=[]

  _sequenceAlways: (block)=>
    @__regAssignList=[]
    @__updateWires=[]
    @__sequenceBlock=[]
    block()
    for seqList in @__sequenceBlock
      for i in seqList.bin
        if i.type=='delay' or i.type=='trigger' or i.type=='event' or i.type=='repeat'
          throw new Error("Can not use delay in always sequence")
    @__sequenceAlwaysList.push(@__sequenceBlock)
    @__sequenceBlock=null
    @__updateWires=[]
    @__regAssignList=[]

  eval: =>
    for evalFunc in @__alwaysList
      evalFunc()

  _hub: (arg)->
    for hubName,list of arg
      #@__addWire(hubName,0) unless this[hubName]?
      for channelPath in list
        #console.log '>>>>add hub',hubName,channelPath
        @__postProcess.push {type:'hub',elName:hubName,bindChannel:channelPath}

  #logic: (expressFunc)=> expressFunc().str

  build: ->

  _getSpace: ->
    if @__indent>0
      return Array(@__indent+1).join('  ')
    else
      return ''

  _regProcess: ()=>
    return {
      _if: (cond)=>
        return (block)=>
          if @__assignInAlways
            @__regAssignList.push @_getSpace()+"if(#{cond.str}) begin"
            @__indent+=1
            block()
            @__indent-=1
            @__regAssignList.push @_getSpace()+"end"
          else if @__assignInSequence
            @__sequenceAssignList.push @_getSpace()+"if(#{cond.str}) begin"
            @__indent+=1
            block()
            @__indent-=1
            @__sequenceAssignList.push @_getSpace()+"end"
          return @_regProcess()
      _elseif: (cond)=>
        return (block)=>
          if @__assignInAlways
            @__regAssignList.push @_getSpace()+"else if(#{cond.str}) begin"
            @__indent+=1
            block()
            @__indent-=1
            @__regAssignList.push @_getSpace()+"end"
          else if @__assignInSequence
            @__sequenceAssignList.push @_getSpace()+"else if(#{cond.str}) begin"
            @__indent+=1
            block()
            @__indent-=1
            @__sequenceAssignList.push @_getSpace()+"end"
          return @_regProcess()
      _else: (block)=>
        if @__assignInAlways
          @__regAssignList.push @_getSpace()+"else begin"
          @__indent+=1
          block()
          @__indent-=1
          @__regAssignList.push @_getSpace()+"end"
        else if @__assignInSequence
          @__sequenceAssignList.push @_getSpace()+"else begin"
          @__indent+=1
          block()
          @__indent-=1
          @__sequenceAssignList.push @_getSpace()+"end"
        return @_regProcess()
      _endif: =>
    }

  _cond: (cond)=>
    return (block)=> {cond:cond.str,value:block()}

  _wireProcess: (list=[])=>
    return {
      _if: (cond)=>
        return (block)=>
          list.push {cond: cond.str, value: block()}
          return @_wireProcess(list)
      _elseif: (cond)=>
        return (block)=>
          list.push {cond: cond.str, value: block()}
          return @_wireProcess(list)
      _else: (block)=>
        list.push {cond: null, value: block()}
        return @_wireProcess(list)
      #_endif: (parallel=false,width=1)=>
      _endif: ()=>
        str=''
        for item,index in list
          if index==0
            str="(#{item.cond})?#{item.value}:"
          else if item.cond?
            str+="(#{item.cond})?#{item.value}:"
          else
            str+="#{item.value}"
        return str
    }

  _reduce: (list,func)=>
    out=null
    for i,index in list
      first=false
      last=false
      if index==0
        first=true
      if index==list.length-1
        last=true
      out= func(out,i,first,last)
    return out

  _reduceRight: (list,func)=>
    out=null
    for i,index in _.clone(list).reverse()
      first=false
      last=false
      if index==0
        first=true
      if index==list.length-1
        last=true
      out= func(out,i,first,last)
    return out

  _if: (cond)->
    if @__assignWaiting
      return @_wireProcess()._if(cond)
    else
      return @_regProcess()._if(cond)

  _pinConnect: ->
    out=[]
    hitPorts={}
    usedPorts={}
    assignList=[]
    for i in @__bindChannels
      #console.log '>>>>',name  for [name,port] in toFlatten(i.port)
      for [name,port] in toFlatten(_.get(@__ports,i.portName))
        hitPorts[toSignal(port.getName())]=1
        if not usedPorts[toSignal(port.getName())]?
          if name!=''
            out.push "  .#{toSignal(port.getName())}( #{i.channel.getName()}__#{toSignal(name)})"
            usedPorts[toSignal(port.getName())]={
              pin:"#{i.channel.getName()}__#{toSignal(name)}"
              port: port
            }
          else
            out.push "  .#{toSignal(port.getName())}( #{i.channel.getName()})"
            usedPorts[toSignal(port.getName())]={
              pin:"#{i.channel.getName()}"
              port:port
            }
        else
          if name!=''
            thisPin="#{i.channel.getName()}__#{toSignal(name)}"
          else
            thisPin="#{i.channel.getName()}"
          usedPort=usedPorts[toSignal(port.getName())]
          if usedPort.port.type=='output'
            assignList.push({from:usedPort.pin,to:thisPin})
          else if usedPort.port.type=='input'
            assignList.push({from:thisPin,to:usedPort.pin})
    for [name,port] in toFlatten(@__ports)
      s=toSignal(port.getName())
      if port.bindSignal?
        out.push "  .#{s}( #{port.bindSignal} )"
      else if not hitPorts[s]?
        out.push "  .#{s}( )"

    return [out,assignList]

  bind: (obj)->
    for port,channel of obj when _.get(@__ports,port)?
      if channel instanceof Channel
        @__bindChannels.push {portName:port, channel: channel}
        portInst = _.get(@__ports,port)
        for [name,sig] in toFlatten(portInst)
          #console.log name,sig
          net=Wire.create(sig.getWidth())
          if name
            wireName=channel.getName()+'__'+name
            net.link(channel.cell,toSignal(wireName))
            netEl=packEl('wire',net)
            _.set(channel.Port,name,netEl)
          else
            wireName=channel.getName()
            net.link(channel.cell,toSignal(wireName))
            netEl=packEl('wire',net)
            channel.Port=netEl

  __link: (name)-> @__instName=name


  _localWire: (width=1,name='t')->
    pWire=Wire.create(Number(width))
    pWire.cell=this
    pWire.setLocal()
    pWire.elName=toSignal(_id('__'+name))
    ret = packEl('wire',pWire)
    @__local_wires.push(ret)
    return ret

  _localReg: (width=1,name='r')=>
    pReg=Reg.create(Number(width))
    pReg.cell=this
    pReg.setLocal()
    pReg.elName=toSignal(_id('__'+name))
    ret = packEl('reg',pReg)
    @__local_regs.push(ret)
    return ret

  _initial: (block)->
    @__sequenceBlock=[]
    block()
    @__initialList.push(@__sequenceBlock)
    @__sequenceBlock=null

  _series: (list...)->
    if @__sequenceBlock==null
      throw new Error("Series should put in initial or sequenceAlways")
    lastSeq=null
    for i,index in list
      seq=i()
      if index>0
        if lastSeq?
          lastCond=_.last(lastSeq.bin)
          lastCond.expr= seq.stateReg.isNthState(0)
          lastCond.id= 'idle'

        startCond={
          type:'wait'
          id:_id('wait')
          expr:lastSeq.stateReg.isLastState()
          list: []
        }
        nextSeq={
          name: seq.name
          stateReg: seq.stateReg
          bin: [startCond,seq.bin...]
        }
        if index==list.length-1
          lastBin=_.last(nextSeq.bin)
          lastBin.id='idle'
          lastBin.type='next'
          lastBin.expr=null
        @__sequenceBlock.pop()
        @__sequenceBlock.push(nextSeq)
      lastSeq=seq

  _sequence: (name,bin=[])->
    if @__sequenceBlock==null
      throw new Error("Sequence only can run in initial or always")
    return {
      delay: (delay) =>
        return (func)=>
          @__assignInSequence=true
          @__sequenceAssignList=[]
          func()
          bin.push({type:'delay',id:_id('delay'),delay:delay,list:@__sequenceAssignList})
          @__assignInSequence=false
          @__sequenceAssignList=[]
          return @_sequence(name,bin)
      repeat: (num)=>
        repeatItem=_.last(bin)
        for i in [0...num]
          bin.push(repeatItem)
        return @_sequence(name,bin)
      event: (trigName)=>
        @__trigMap[trigName]=1
        bin.push({type:'event',id:_id('event'),event:trigName,list:[]})
        return @_sequence(name,bin)
      trigger: (signal)=>
        return (func)=>
          @__assignInSequence=true
          @__sequenceAssignList=[]
          func()
          bin.push({type:'trigger',id:_id('trigger'),signal:signal,list:@__sequenceAssignList})
          @__assignInSequence=false
          @__sequenceAssignList=[]
          return @_sequence(name,bin)
      posedge: (signal,stepName=null)=>
        return (func)=>
          expr=@_rise(signal)
          @__assignInSequence=true
          @__sequenceAssignList=[]
          func()
          id = stepName ? _id('rise')
          bin.push({type:'posedge',id:id,expr:expr,list:@__sequenceAssignList})
          @__assignInSequence=false
          @__sequenceAssignList=[]
          return @_sequence(name,bin)
      negedge: (signal,stepName=null)=>
        return (func)=>
          expr=@_fall(signal)
          active=@_localWire(1,'act')
          @__assignInSequence=true
          @__sequenceAssignList=[]
          func(active)
          id = stepName ? _id('fall')
          bin.push({type:'negedge',id:id,expr:expr,list:@__sequenceAssignList,active:active})
          @__sequenceAssignList=[]
          @__assignInSequence=false
          return @_sequence(name,bin)
      wait: (expr,stepName=null)=>
        return (func)=>
          @__assignInSequence=true
          @__sequenceAssignList=[]
          func()
          id = stepName ? _id('wait')
          bin.push({type:'wait',id:id,expr:expr,list:@__sequenceAssignList})
          @__assignInSequence=false
          @__sequenceAssignList=[]
          return @_sequence(name,bin)
      next: (num=null,stepName=null)=>
        return (func)=>
          if num==null
            expr=null
            enable=null
          else
            enable=@_localWire(1,'enable')
            expr=@_count(num,enable.getName())
          @__assignInSequence=true
          @__sequenceAssignList=[]
          func()
          id = stepName ? _id('next')
          bin.push({type:'next',id:id,expr:expr,enable:enable,list:@__sequenceAssignList})
          @__assignInSequence=false
          @__sequenceAssignList=[]
          return @_sequence(name,bin)
      end: ()=>
        stateNum=1
        for i in bin
          stateNum+=1
        bitWidth=Math.floor(Math.log2(stateNum))+1
        stateReg=@_localReg(bitWidth,name)
        lastStateReg=@_localReg(bitWidth,name+'_last')
        stateNameList=['idle']
        for i in bin
          stateNameList.push(i.id)
        stateReg.stateDef(stateNameList)
        lastStateReg.stateDef(stateNameList)
        finalJump=_.clone(bin[0])
        finalJump.list=[]
        finalJump.isLast=true
        bin.push(finalJump)
        saveData={name:name,bin:bin,stateReg:stateReg}
        @__sequenceBlock.push saveData
        for i in bin when i.type=='next' and i.enable?
          @_assign(i.enable) => stateReg.isState(i.id)
        for i,index in bin when i.active?
          @_assign(i.active) => stateReg.isState(i.id) && lastStateReg.isState(bin[index-1].id)
        return saveData
    }

  verilog: (s)->
    if @__assignInSequence
      @__sequenceAssignList.push s
    else
      @__regAssignList.push s

  _clean: ->
    keys=Object.keys(@__signature)
    for i in keys
      delete @__signature[i]
          
          
  __getPath:(cell=null,list=[])->
    cell=this if cell==null
    if cell.__parentNode==null
      list.push(cell.__moduleName)
      return list.reverse().join('.')
    else
      list.push(cell.__instName)
      @__getPath(cell.__parentNode,list)

  _assign: (signal)=>
    if _.isPlainObject(signal) or _.isArray(signal)
      return (block)=>
        if _.isFunction(block)
          obj=block()
        else
          obj=block
        list=toFlatten(obj)
        for [path,item] in list
          el=_.get(signal,path)
          if el?
            if _.isFunction(item)
              el.assign(item)
            else
              el.assign(->item)
    else if _.isFunction(signal)
      return (block)->
        if _.isFunction(block)
          signal().assign(block)
        else
          signal().assign(->block)
    else
      return (block)->
        if _.isFunction(block)
          signal.assign(block)
        else
          signal.assign(->block)

  __parameterDeclare: ->
    out=''
    if @__moduleParameter?
      for i in @__moduleParameter
        out+="parameter #{i.key} = #{i.value};\n"
    return out
      
module.exports=Module
