Port    = require 'chdl_port'
Expr    = require 'chdl_expr'
Reg     = require 'chdl_reg'
Wire    = require 'chdl_wire'
Channel = require 'chdl_channel'
{table} = require 'table'
{toEventList,rhsTraceExpand,packEl,toSignal,toHier,toFlatten}=require('chdl_utils')
_ = require 'lodash'
log    =  require 'fancy-log'
uuid  = require 'uuid/v1'

localCnt=0

_id=(name)=>
  ret="#{name}_#{localCnt}"
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
    obj.init.call(this) if obj.init?

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
      @[name]=inst

  _getCell: (name)=>
    p=Object.getPrototypeOf(this)
    for k,v of p when typeof(v)=='object' and v instanceof Module
      return v if k==name
    return _.find(@__cells,{name:name})

  _setConfig: (v) -> @__config=v

  _reg: (obj) ->
    for k,v of obj
      @__regs[k]=v
      if this[k]?
        throw new Error('Register name conflicted '+k)
      else
        this[k]=v
        for [name,inst] in toFlatten(v,'reg')
          inst.link(this,toHier(k,name))
          inst.setGlobal()

  _wire: (obj) ->
    for k,v of obj
      @__wires[k]=v
      if this[k]?
        throw new Error('Wire name conflicted '+k)
      else
        this[k]=v
        for [name,inst] in toFlatten(v,'wire')
          inst.link(this,toHier(k,name))
          inst.setGlobal()

  _mem: (obj) ->
    for k,v of obj
      @__vecs[k]=v
      if this[k]?
        throw new Error('Vec name conflicted '+k)
      else
        this[k]=v
        for [name,inst] in toFlatten(v,'vec')
          inst.link(this,toHier(k,name))

  _channel: (obj) ->
    for k,v of obj
      @__channels[k]=v
      if this[k]?
        throw new Error('Channel name conflicted '+k)
      else
        for [name,inst] in toFlatten(v,'channel')
          inst.link(this,toHier(k,name))
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
        for [name,inst] in toFlatten(v,'port')
          sigName=toSignal(k+'.'+name)
          hierName=toHier(k,name)
          inst.link(this,hierName)
          if inst.isClock
            @_setDefaultClock(sigName)
          if inst.isReset
            @_setDefaultReset(sigName)
          if inst.isReg
            createReg=new Reg(inst.getWidth())
            createReg.config(inst.isRegConfig)
            @__regs[sigName]=createReg
            createReg.link(this,sigName)
            inst.setShadowReg(createReg)

  _overrideModuleName: (name)-> @__moduleName=name
  setUniq: -> @__uniq=true
  notUniq: -> @__uniq=false
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
    @__foreverList     =  []
    @__regs           =  {}
    @__wires          =  {}
    @__local_wires      =  []
    @__local_regs      =  []
    @__vecs           =  {}
    @__channels       =  {}
    @__ports          =  {}
    @__wireAssignList =  []
    @__initialList=[]
    @__initialMode=false
    @__sequenceBlock=null
    @__cells      =[]
    @__uniq       = true

    @__bindChannels=[]
    @__defaultClock=null
    @__defaultReset=null

    @__regAssignList=[]
    @__trigMap={}
    @__assignWidth=null
    @__updateWires=[]
    @__assignWaiting=false
    @__assignEnv=null
    @__parentNode=null
    @__indent=0
    @__postProcess=[]
    @__isBlackBox=false
    @__specify=false
    @__specifyModuleName=null
    @__autoClock=true
    @__pinAssign=[]
    @_mixin require('chdl_primitive_lib.chdl.js')
    @__sim=false

  _setSim: ->
    @__sim=true

  _setParentNode: (node)->
    @__parentNode=node

  _setDefaultClock: (clock)->
    if @__defaultClock==null
      @__defaultClock=clock

  _setDefaultReset: (reset)->
    if @__defaultReset==null
      @__defaultReset=reset

  setDefaultClock: (clock)=>
    @__defaultClock=clock

  setDefaultReset: (reset)=>
    @__defaultReset=reset

  _clock: => @__defaultClock
  _reset: => @__defaultReset

  setBlackBox: ()=> @__isBlackBox=true

  isBlackBox: ()=> @__isBlackBox

  disableAutoClock: ()=> @__autoClock=false

  _getChannelWire: (channelName,path=null)->
    if @__channels[channelName]?
      return @__channels[channelName].getWire(path)
    else
      console.error 'Channel',channelName,'not found'
      console.trace()

  _dumpPort: ->
    out={}
    for [name,item] in toFlatten(@__ports)
      _.set(out,name,{dir:item.getType(),width:item.getWidth(),sigName:toSignal(item.getName())})
    return out

  _dumpReg: ->
    out={}
    for [name,item] in toFlatten(@__regs)
      if item.constructor.name=='Reg'
        _.set(out,name,{width:item.getWidth(),property:item.simProperty(),simList:item.simList()})
    return out

  _dumpVar: ->
    out={}
    for [name,item] in toFlatten(@__regs)
      if item.constructor.name=='Vreg'
        _.set(out,name,{width:item.getWidth()})
    return out

  _dumpWire: ->
    out={}
    for [name,item] in toFlatten(@__wires)
      _.set(out,name,{width:item.getWidth(),simList:item.simList()})
    return out

  _addWire: (name,width)->
    wire= Wire.create(width)
    wire.link(this,name)
    pack=packEl('wire',wire)
    @__wires[name]=pack
    this[name]=pack
    return wire

  _addPort: (name,dir,width)->
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

  _dragPort: (inst,dir,width,pathList,portName)->
    nextInst=_.get(inst,pathList[0])
    if nextInst? and nextInst instanceof Module
      newPortName=toSignal([pathList[1..]...,portName].join('.'))
      port=nextInst._addPort(newPortName,dir,width)
      if port?
        port.setBindSignal(toSignal([pathList...,portName].join('.')))
        #nextInst.addWire(newPortName,width)
        #nextInst.dumpPorts()
        @_dragPort(nextInst,dir,width,pathList[1..],portName)

  _removeNode:(list)->
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

  _findChannel: (inst,list)->
    if _.get(inst,list)?
      return _.get(inst,list)

    if list.length==1
      out=inst.__channels[list[0]]
      return out
    else
      nextInst=inst[list[0]]
      return @_findChannel(nextInst,list.slice(1))

  _channelExpand:(channelType,localName,channelInfo)->
    localport=null
    nodeList=[]
    #if channelType=='hub'
    #  nodeList=_.toPath(localName)
    #else
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
        #@__removeNode(nodeList) if channelType!='hub'
        @_removeNode(nodeList)

    if _.isString(channelInfo)
      channel=@_findChannel(this,_.toPath(channelInfo))
      channelName=channelInfo
    else
      channel=channelInfo
      channelName=channelInfo.getName()
    for obj in channel.portList
      bindPort=obj.port
      dir=bindPort.type
      width=bindPort.width
      @_dragPort(this,dir,width,_.toPath(channelName),obj.node.join('.'))
      if dir=='output' or dir=='input'
        wireName=toSignal([channelName,obj.node...].join('.'))
        wire=@_addWire(wireName,width)
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
            netEl.setType(dir)
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

  _postElaboration: ->
    for i in @__postProcess
      @_channelExpand(i.type,i.elName,i.bindChannel)

  _elaboration: ->
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

  _always: (lineno,block)=>
    @__assignEnv = 'always'
    if @__assignWaiting
      assignWaitingSave=true
      @__assignWaiting=false
    else
      assignWaitingSave=false
    @__regAssignList=[]
    @__updateWires=[]
    @__sequenceBlock=[]
    block()
    if @__sequenceBlock.length>0
      for seqList in @__sequenceBlock
        for i in seqList.bin
          if i.type=='delay' or i.type=='trigger' or i.type=='event' or i.type=='repeat'
            throw new Error("Can not use delay in always sequence")
        @_buildSeqBlock(seqList)
      @__sequenceBlock=null
    @__alwaysList.push([@__regAssignList,@__updateWires,lineno])
    for i in @__updateWires
      i.inst.share.alwaysList=@__regAssignList
    @__assignEnv = null
    @__updateWires=[]
    @__regAssignList=[]
    if assignWaitingSave
      @__assignWaiting=true

  _always_if: (cond,lineno)=>
    return (block)=>
      @__assignEnv = 'always'
      @__regAssignList=[]
      @__updateWires=[]
      @_regProcess()._if(cond,lineno)(block)._endif()
      @__alwaysList.push([@__regAssignList,@__updateWires,lineno])
      for i in @__updateWires
        i.inst.share.alwaysList=@__regAssignList
      @__assignEnv = null
      @__updateWires=[]
      @__regAssignList=[]

  _passAlways: (lineno,block)=>
    @__assignEnv = 'always'
    @__regAssignList=[]
    @__updateWires=[]
    block()
    @__alwaysList.push([@__regAssignList,[],lineno])
    @__assignEnv = null
    @__updateWires=[]
    @__regAssignList=[]

  eval: =>
    for evalFunc in @__alwaysList
      evalFunc()

  #_hub: (arg)->
  #  for hubName,list of arg
  #    #@_addWire(hubName,0) unless this[hubName]?
  #    for channelPath in list
  #      #console.log '>>>>add hub',hubName,channelPath
  #      @__postProcess.push {type:'hub',elName:hubName,bindChannel:channelPath}

  #logic: (expressFunc)=> expressFunc().str

  build: ->

  _getSpace: ->
    if @__indent>0
      return Array(@__indent+1).join('  ')
    else
      return ''

  _if_blocks: (list)=>
    ret=null
    for item,index in list
      if index==0
        ret=@_regProcess()._if(item.cond,item.lineno)(item.value)
      else
        if item.cond? and item.cond.str!='null'
          ret=ret._elseif(item.cond,item.lineno)(item.value)
        else
          ret=ret._else(item.lineno)(item.value)
    ret._endif()

  _regProcess: ()=>
    return {
      _if: (cond,lineno)=>
        return (block)=>
          @__regAssignList.push ["if","#{cond.str}",lineno]
          @__indent+=1
          block()
          @__indent-=1
          @__regAssignList.push ["end"]
          return @_regProcess()
      _elseif: (cond,lineno=-1)=>
        return (block)=>
          @__regAssignList.push ["elseif","#{cond.str}",lineno]
          @__indent+=1
          block()
          @__indent-=1
          @__regAssignList.push ["end"]
          return @_regProcess()
      _else: (lineno)=>
        return (block)=>
          @__regAssignList.push ["else",lineno]
          @__indent+=1
          block()
          @__indent-=1
          @__regAssignList.push ["end"]
          return @_regProcess()
      _endif: =>
          @__regAssignList.push ["endif"]
    }

  _cond: (cond=null,lineno=-1)=>
    return (block)=>
      if block?
        value=block()
        {cond:cond,value:(=>value),lineno:lineno}
      else
        {cond:cond,value:null,lineno:lineno}

  _lazy_cond: (cond=null,lineno=-1)=>
    return (block)=> {cond:cond,value:block,lineno:lineno}

  _wireProcess: (list=[],lineno)=>
    return {
      _if: (cond,lineno)=>
        return (block)=>
          list.push {cond: cond.str, value: block(),lineno:lineno}
          return @_wireProcess(list)
      _elseif: (cond,lineno)=>
        return (block)=>
          list.push {cond: cond.str, value: block(),lineno:lineno}
          return @_wireProcess(list)
      _else: (lineno)=>
        return (block)=>
          list.push {cond: null, value: block(),lineno:lineno}
          return @_wireProcess(list)
      _endif: ()=>
        if _.last(list).cond!=null
          throw new Error("Please set default value for condition assign")
        return list
        #str=''
        #for item,index in list
        #  if item.lineno>=0
        #    anno="/*#{item.lineno}*/"
        #  else
        #    anno=""
        #  if index==0
        #    str="(#{item.cond}#{anno})?#{item.value}:"
        #  else if item.cond?
        #    str+="(#{item.cond}#{anno})?#{item.value}:"
        #  else
        #    str+="#{item.value}#{anno}"
        #return str
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

  _if: (cond,lineno=-1)->
    if @__assignWaiting
      return @_wireProcess()._if(cond,lineno)
    else if @__assignEnv=='always'
      return @_regProcess()._if(cond,lineno)
    else
      return @_wireProcess()._if(cond,lineno)
    #return @_regProcess()._if(cond,lineno)

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
          if usedPort.pin!=thisPin
            if usedPort.port.type=='output'
              assignList.push({from:usedPort.pin,to:thisPin})
            else if usedPort.port.type=='input'
              assignList.push({from:thisPin,to:usedPort.pin})
    for [name,port] in toFlatten(@__ports)
      s=toSignal(port.getName())
      if not usedPorts[s]?
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
            net.link(channel.cell,toHier(channel.hier,name))
            netEl=packEl('wire',net)
            netEl.setType(sig.getType())
            _.set(channel.Port,name,netEl)
          else
            net.link(channel.cell,channel.hier)
            netEl=packEl('wire',net)
            netEl.setType(sig.getType())
            channel.Port=netEl

  _link: (name)-> @__instName=name

  _localWire: (width=1,name='t')->
    pWire=Wire.create(Number(width))
    pWire.cell=this
    pWire.setLocal()
    pWire.elName=toSignal(_id('__'+name))
    pWire.hier=pWire.elName
    ret = packEl('wire',pWire)
    @__local_wires.push(ret)
    return ret

  _localReg: (width=1,name='r')=>
    pReg=Reg.create(Number(width))
    pReg.cell=this
    pReg.setLocal()
    pReg.elName=toSignal(_id('__'+name))
    pReg.hier=pReg.elName
    ret = packEl('reg',pReg)
    @__local_regs.push(ret)
    return ret

  _initial: (lineno,block)->
    @__sequenceBlock=[]
    @__initialMode=true
    block()
    @__initialList.push(@__sequenceBlock)
    @__initialMode=false
    @__sequenceBlock=null

  _forever: (lineno,block)->
    @__sequenceBlock=[]
    @__initialMode=true
    block()
    @__foreverList.push(@__sequenceBlock)
    @__initialMode=false
    @__sequenceBlock=null

  _sequenceDef: (name='sequence',clock='',reset='')=>
    if @__sequenceBlock==null
      throw new Error("Sequence only can run in initial or always")

    return @_sequence(_id(name+'_'),[],clock,reset)

  _sequence: (name,bin=[],clock,reset)->
    env='always'
    ret = {
      init: (func)=>
        if @__initialMode
          @__assignEnv='always'
          @__regAssignList=[]
          func()
          bin.push({type:'idle',id:'idle',list:@__regAssignList,next:null})
          @__assignEnv=null
          @__regAssignList=[]
        else
          next=@_localWire(1,'next')
          @__assignEnv='always'
          @__regAssignList=[]
          bin.push({type:'idle',id:'idle',list:@__regAssignList,next:next,func:func})
          @__assignEnv=null
          @__regAssignList=[]
        return @_sequence(_id(name+'_'),bin,clock,reset)
      do: (func) =>
        @__assignEnv=env
        @__regAssignList=[]
        func()
        bin.push({type:'delay',id:_id('delay'),delay:null,list:@__regAssignList})
        @__assignEnv=null
        @__regAssignList=[]
        return @_sequence(name,bin,clock,reset)
      delay: (delay) =>
        return (func)=>
          @__assignEnv=env
          @__regAssignList=[]
          func()
          bin.push({type:'delay',id:_id('delay'),delay:delay,list:@__regAssignList})
          @__assignEnv=null
          @__regAssignList=[]
          return @_sequence(name,bin,clock,reset)
      then: () =>
        return (func)=>
          @__assignEnv=env
          @__regAssignList=[]
          func(ret)
          #bin.push({type:'then',id:_id('then'),list:@__regAssignList})
          @__assignEnv=null
          @__regAssignList=[]
          return @_sequence(name,bin,clock,reset)
      repeat: (num)=>
        repeatItem=_.last(bin)
        for i in [0...num]
          bin.push(repeatItem)
        return @_sequence(name,bin,clock,reset)
      event: (trigName)=>
        @__trigMap[trigName]=1
        bin.push({type:'event',id:_id('event'),event:trigName,list:[]})
        return @_sequence(name,bin,clock,reset)
      trigger: (signal)=>
        return (func)=>
          @__assignEnv=env
          @__regAssignList=[]
          func()
          bin.push({type:'trigger',id:_id('trigger'),signal:signal,list:@__regAssignList})
          @__assignEnv=null
          @__regAssignList=[]
          return @_sequence(name,bin,clock,reset)
      polling: (signal,expr, stepName=null)=>
        return (func)=>
          if @__initialMode
            @__assignEnv=env
            @__regAssignList=[]
            func()
            id = stepName ? _id('poll')
            bin.push({type:'polling',id:id,expr:expr,list:@__regAssignList,active:null,next:null,signal:signal.getName()})
            @__assignEnv=null
            @__regAssignList=[]
          return @_sequence(name,bin,clock,reset)
      posedge: (signal,stepName=null)=>
        return (func)=>
          if @__initialMode
            @__assignEnv=env
            @__regAssignList=[]
            func()
            id = stepName ? _id('rise')
            bin.push({type:'posedge',id:id,expr:null,list:@__regAssignList,active:null,next:null,signal:signal.getName()})
            @__assignEnv=null
            @__regAssignList=[]
          else
            expr=@_rise(signal,clock)
            active=@_localWire(1,'trans')
            next=@_localWire(1,'next')
            @__assignEnv=env
            @__regAssignList=[]
            id = stepName ? _id('rise')
            bin.push({type:'posedge',id:id,expr:expr,list:@__regAssignList,active:active,next:next,signal:signal.getName(),func:func})
            @__assignEnv=null
            @__regAssignList=[]
          return @_sequence(name,bin,clock,reset)
      negedge: (signal,stepName=null)=>
        return (func)=>
          if @__initialMode
            @__assignEnv=env
            @__regAssignList=[]
            func()
            id = stepName ? _id('fall')
            bin.push({type:'negedge',id:id,expr:null,list:@__regAssignList,active:null,next:null,signal:signal.getName()})
            @__assignEnv=null
            @__regAssignList=[]
          else
            expr=@_fall(signal,clock)
            active=@_localWire(1,'trans')
            next=@_localWire(1,'next')
            @__assignEnv=env
            @__regAssignList=[]
            id = stepName ? _id('fall')
            bin.push({type:'negedge',id:id,expr:expr,list:@__regAssignList,active:active,next:next,signal:signal.getName(),func:func})
            @__assignEnv=null
            @__regAssignList=[]
          return @_sequence(name,bin,clock,reset)
      wait: (expr,stepName=null)=>
        return (func)=>
          if @__initialMode
            @__assignEnv=env
            @__regAssignList=[]
            func()
            id = stepName ? _id('wait')
            bin.push({type:'wait',id:id,expr:expr,list:@__regAssignList,active:null,next:null})
            @__assignEnv=null
            @__regAssignList=[]
          else
            @__assignEnv=env
            @__regAssignList=[]
            active=@_localWire(1,'trans')
            next=@_localWire(1,'next')
            id = stepName ? _id('wait')
            bin.push({type:'wait',id:id,expr:expr,list:@__regAssignList,active:active,next:next,func:func})
            @__assignEnv=null
            @__regAssignList=[]
          return @_sequence(name,bin,clock,reset)
      next: (num=null,signal=null,stepName=null)=>
        return (func)=>
          if @__initialMode
            throw new Error("next not supported in initial")
          else
            if num==null
              expr=null
              enable=null
            else
              enable=@_localWire(1,'enable')
              expr=@_count(num,enable,0)
            active=@_localWire(1,'trans')
            next=@_localWire(1,'next')
            @__assignEnv=env
            @__regAssignList=[]
            id = stepName ? _id('next_cycle')
            bin.push({type:'next',id:id,expr:expr,enable:enable,list:@__regAssignList,active:active,next:next,func:func})
            @__assignEnv=null
            @__regAssignList=[]
            return @_sequence(name,bin,clock,reset)
      end: ()=>
        if bin[0].type!='idle'
          bin.unshift({type:'idle',id:'idle',list:[],next:null,func:null})
        if @__initialMode
          saveData={name:name,bin:bin,stateReg:null,update:@__updateWires,nextState:null}
          @__sequenceBlock.push saveData
          @__updateWires=[]
        else
          bitWidth=Math.floor(Math.log2(bin.length))+1
          stateReg=@_localReg(bitWidth,name).clock(clock).reset(reset)
          lastStateReg=@_localReg(bitWidth,name+'_last').clock(clock).reset(reset)
          nextState=@_localWire(bitWidth,name+'_next')
          stateNameList=[]
          for i in bin
            stateNameList.push(i.id)
          stateReg.stateDef(stateNameList)
          lastStateReg.stateDef(stateNameList)

          finalJump=_.clone(bin[1])
          finalJump.list=[]
          finalJump.isLast=true
          finalJump.next=null
          finalJump.func=null
          bin.push(finalJump)

          retData={name:name,bin:bin,stateReg:stateReg,update:@__updateWires,nextState:nextState}
          @__sequenceBlock.push retData
          @__updateWires=[]
          @_seqState(stateReg,nextState,lastStateReg,bin)

        return retData
    }
    return ret

  verilog: (s)->
    @__regAssignList.push ['verilog',s]

  _clean: ->
    keys=Object.keys(@__signature)
    for i in keys
      delete @__signature[i]
          
  _getPath:(cell=null,list=[])->
    cell=this if cell==null
    if cell.__parentNode==null
      list.push(cell.__moduleName)
      return list.reverse().join('.')
    else
      list.push(cell.__instName)
      @_getPath(cell.__parentNode,list)

  _assign: (signal,lineno=-1)=>
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
              el.assign(item,lineno)
            else
              el.assign((->item),lineno)
    else if _.isFunction(signal)
      return (block)->
        if _.isFunction(block)
          signal().assign(block,lineno)
        else
          signal().assign((->block),lineno)
    else
      return (block)->
        if _.isFunction(block)
          if signal?
            signal.assign(block,lineno)
          else
            throw new Error("Assign to signal is undefined at line: #{lineno}")
        else
          signal.assign((->block),lineno)

  _while: (cond)=>
    if @__sequenceBlock==null
      throw new Error("while only can run in initial")

    return (func)=>
      if @__initialMode
        @__sequenceBlock.push {isTag:true,tagType:'while_begin',cond:cond.str}
        func()
        @__sequenceBlock.push {isTag:true,tagType:'while_end'}
      else
        throw new Error("while only can run in initial")

  _when: (cond)=>
    if @__sequenceBlock==null
      throw new Error("when only can run in initial")

    return (func)=>
      if @__initialMode
        @__sequenceBlock.push {isTag:true,tagType:'when_begin',cond:cond.str}
        func()
        @__sequenceBlock.push {isTag:true,tagType:'when_end'}
      else
        throw new Error("while only can run in initial")


  _parameterDeclare: ->
    out=''
    if @__moduleParameter?
      for i in @__moduleParameter
        out+="parameter #{i.key} = #{i.value};\n"
    return out

  _dumpEvent: =>
    out=[]
    for seqBlock in @__initialList when seqBlock.length>0
      seq={type:'initial',list:[]}
      out.push seq
      for item in seqBlock
        toEventList(item.bin,seq.list)
    for seqBlock in @__foreverList when seqBlock.length>0
      seq={type:'forever',list:[]}
      out.push seq
      for item in seqBlock
        toEventList(item.bin,seq.list)
    return out

  _dumpCell: =>
    p = Object.getPrototypeOf(this)
    cellList=({inst:k,module:v.getModuleName()} for k,v of p when typeof(v)=='object' and v instanceof Module)
    for i in @__cells
      cellList.push({inst:i.name,module:i.inst.getModuleName()}) unless _.find(cellList,(n)-> n.inst.__id==i.inst.__id)
    for cellInfo in cellList
      cellInst=@_getCell(cellInfo.inst)
      connList=[]
      for i in cellInst.__bindChannels
        connList.push {port:i.portName,channel:i.channel.hier}
      cellInfo.conn=connList
      if cellInst.__defaultClock
        clockPort=cellInst.__ports[cellInst.__defaultClock]
        if not clockPort.isBinded()
          connList.push {port:clockPort.elName,signal:@__defaultClock}
      if cellInst.__defaultReset
        resetPort=cellInst.__ports[cellInst.__defaultReset]
        if not resetPort.isBinded()
          connList.push {port:resetPort.elName,signal:@__defaultReset}
    return cellList

  _dumpChannel: =>
    out={}
    for [name,channel] in toFlatten(@__channels)
      for [path,port] in toFlatten(channel.Port)
        hier=do ->
          if path!=''
            channel.hier+'.Port.'+path
          else
            channel.hier+'.Port'
        _.set(out,hier,{width:port.getWidth(),simList:port.simList()})

    return out
    

module.exports=Module
