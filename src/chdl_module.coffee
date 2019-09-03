Port    = require 'chdl_port'
Expr    = require 'chdl_expr'
Reg     = require 'chdl_reg'
Wire    = require 'chdl_wire'
Channel = require 'chdl_channel'
ElementSets = require 'chdl_el_sets'
{packEl,toSignal,toFlatten}=require('chdl_utils')
_ = require 'lodash'
log    =  require 'fancy-log'
uuid  = require 'uuid/v1'

class Module
  @create: (args...)-> new this(args...)

  __instName: ''

  __signature:{}

  _cellmap: (v) ->
    for name,inst of v
      @__cells.push({name:name,inst:inst})

  __getCell: (name)=>
    p=Object.getPrototypeOf(this)
    for k,v of p when typeof(v)=='object' and v instanceof Module
      return v if k==name
    return _.find(@__cells,{name:name})

  _reg: (obj) ->
    for k,v of obj
      @__regs[k]=v
      if this[k]?
        throw new Error('Register name conflicted '+k)
      else
        this[k]=v

  _wire: (obj) ->
    for k,v of obj
      @__wires[k]=v
      if this[k]?
        throw new Error('Wire name conflicted '+k)
      else
        this[k]=v

  _mem: (obj) ->
    for k,v of obj
      @__vecs[k]=v
      if this[k]?
        throw new Error('Vec name conflicted '+k)
      else
        this[k]=v

  _channel: (obj) ->
    for k,v of obj
      @__channels[k]=v
      if this[k]?
        throw new Error('Channel name conflicted '+k)
      else
        this[k]=v

  _probe: (obj) ->
    for k,v of obj
      @__channels[k]=Channel.create(v)
      if this[k]?
        throw new Error('Channel name conflicted '+k)
      else
        this[k]=@__channels[k]

  _port: (obj) ->
    for k,v of obj
      @__ports[k]=v
      @__wires[k]=v
      if this[k]?
        throw new Error('Port name conflicted '+k)
      else
        this[k]=v
        for [name,port] in toFlatten({[k]:v})
          if port.isClock
            @__setDefaultClock(name)
          if port.isReset
            @__setDefaultReset(name)

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
    @__pureAlwaysList     =  []
    @__pipeAlwaysList =  []
    @__regs           =  {}
    @__pipeRegs       =  []
    @__wires          =  {}
    @__vecs           =  {}
    @__channels       =  {}
    @__ports          =  {}
    @__wireAssignList =  []
    @__initialList=[]
    @__cells      =[]

    @__pipe={}
    @__pipeNewRegs=[]
    @__pipeName=null
    @__bindChannels=[]
    @__defaultClock=null
    @__defaultReset=null

    @__regAssignList=[]
    @__assignWidth=null
    @__updateWires=[]
    @__assignWaiting=false
    @__assignInAlways=false
    @__parentNode=null
    @__indent=0
    @__postProcess=[]
    @__isBlackBox=false
    @__specify=false
    @__specifyModuleName=null
    @__autoClock=true

  __setParentNode: (node)->
    @__parentNode=node

  __setDefaultClock: (clock)->
    @__defaultClock=clock if @__defaultClock==null

  __setDefaultReset: (reset)->
    @__defaultReset=reset if @__defaultReset==null

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
      s=toSignal(port.elName)
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

  __addChannel: (name)->
    channel=Channel.create()
    channel.link(this,name)
    @__channels[name]=channel

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

    getPort= (cell,path)->
      for [name,port] in toFlatten(cell.__ports)
        return port if _.isEqual(_.toPath(name),_.toPath(path))
      return null


    if _.isString(channelInfo)
      channel=@__findChannel(this,_.toPath(channelInfo))
      channelName=channelInfo
    else
      channel=channelInfo
      channelName=channelInfo.elName
    for obj in channel.portList
      bindPort=getPort(obj.cell,obj.path)
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
          _.set(this,newPath,netEl)
          _.set(@__ports,newPath,netEl)
          _.set(@__wires,newPath,netEl)
        else
          net=Wire.create(width)
          net.link(this,toSignal(newPath))
          netEl=packEl('wire',net)
          _.set(this,newPath,netEl)
          _.set(@__wires,newPath,netEl)
        if dir=='input'
          if type=='Wire'
            wire.assign(->toSignal(net.elName))
          else
            wire.assign(->toSignal(newPath))
        else if dir=='output'
          net.assign(->wire.elName)

    for i in @__bindChannels
      i.channel.portList.length=0
      i.channel.bindPort(this,i.portName)

  __postElaboration: ->
    for i in @__postProcess
      @__channelExpand(i.type,i.elName,i.bindChannel)

  __elaboration: ->
    for [name,port] in toFlatten(@__ports)
      port.link(this,toSignal(name))
      if port.isReg
        createReg=new Reg(port.getWidth())
        createReg.config(port.isRegConfig)
        @__regs[toSignal(name)]=createReg
      #log 'elaboration port',this.constructor.name,name,port.elName
      if port.type==null
        @__postProcess.push {type:'port',elName:port.elName,bindChannel:port.bindChannel}
    for [name,wire] in toFlatten(@__wires)
      #log 'elaboration wire',this.constructor.name,name,wire.elName
      wire.link(this,toSignal(name))
      #if wire.width==0
      #  @__postProcess.push {type:'wire',elName:wire.elName,bindChannel:wire.bindChannel}
    for [name,reg] in toFlatten(@__regs)
      #log 'elaboration reg',this.constructor.name,name
      reg.link(this,toSignal(name))
    for [name,vec] in toFlatten(@__vecs)
      #log 'elaboration vec',this.constructor.name,name
      vec.link(this,toSignal(name))
    for [name,channel] in toFlatten(@__channels)
      #log 'elaboration channel',this.constructor.name,name
      channel.link(this,toSignal(name))
      if channel.aliasPath?
        @__postProcess.push {type:'channel',elName:name,bindChannel:channel.aliasPath}

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

  __pipeAlways: (block)=>
    @__assignInAlways=true
    @__regAssignList=[]
    block(@__pipe)
    @__pipeAlwaysList.push({name:@__pipeName, list:@__regAssignList,regs:@__pipeNewRegs})
    @__assignInAlways=false
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

  _expr: (s)=> s.str

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
          @__regAssignList.push @_getSpace()+"if(#{cond.str}) begin"
          @__indent+=1
          block()
          @__indent-=1
          @__regAssignList.push @_getSpace()+"end"
          return @_regProcess()
      _elseif: (cond)=>
        return (block)=>
          @__regAssignList.push @_getSpace()+"else if(#{cond.str}) begin"
          @__indent+=1
          block()
          @__indent-=1
          @__regAssignList.push @_getSpace()+"end"
          return @_regProcess()
      _else: (block)=>
        @__regAssignList.push @_getSpace()+"else begin"
        @__indent+=1
        block()
        @__indent-=1
        @__regAssignList.push @_getSpace()+"end"
        return @_regProcess()
      _endif: =>
    }

  _cond: (cond)=>
    return (block)=> {cond:cond.str,value:block()}

  _default: ()=>
    return (block)=> {cond:'',value:block()}

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

  _caseProcess: (w)=>
    if _.isString(w)
      width=Number(w)
    else if _.isNumber(w)
      width=w
    else
      width=w.str
    return (list)=>
      plist=[]
      first=true
      for {cond,value} in list
        if first
          if width>1
            plist.push "({#{width}{#{cond}}}&(#{value}))"
          else
            plist.push "((#{cond})&(#{value}))"
          first=false
        else
          if width>1
            plist.push "        ({#{width}{#{cond}}}&(#{value}))"
          else
            plist.push "        ((#{cond})&(#{value}))"
      return plist.join('|\n')

  _expandProcess: (w)=>
    width=w.str
    return (block)=>
      if _.isFunction(block)
        obj=block()
      else
        obj=block
      return  "{#{width}{#{obj}}}"

  _orderProcess: (default_expr)=>
    return (list)=>
      plist=[]
      first=true
      for {cond,value} in list[0]
        if first
          plist.push "(#{cond})?(#{value}):"
          first=false
        else
          plist.push "        (#{cond})?(#{value}):"

      plist.push "        (#{list[1]})"
      return plist.join('\n')
      
  _if: (cond)->
    if @__assignWaiting
      return @_wireProcess()._if(cond)
    else
      return @_regProcess()._if(cond)

  _pinConnect: ->
    out=[]
    hitPorts={}
    for i in @__bindChannels
      #console.log '>>>>',name  for [name,port] in toFlatten(i.port)
      for [name,port] in toFlatten(_.get(@__ports,i.portName))
        hitPorts[toSignal(port.elName)]=1
        if name!=''
          out.push "  .#{toSignal(port.elName)}( #{i.channel.elName}__#{toSignal(name)})"
        else
          out.push "  .#{toSignal(port.elName)}( #{i.channel.elName})"
    for [name,port] in toFlatten(@__ports)
      s=toSignal(port.elName)
      if port.bindSignal?
        out.push "  .#{s}( #{port.bindSignal} )"
      else if not hitPorts[s]?
        out.push "  .#{s}( )"
    return out

  bind: (obj)->
    for port,channel of obj when _.get(@__ports,port)?
      if channel instanceof Channel
        @__bindChannels.push {portName:port, channel: channel}

  __link: (name)-> @__instName=name

  _assignPipe: (obj,w=1)->
    if _.isString(obj)
      name=obj
      width=w
      pReg=Reg.create(Number(width))
      pReg.cell=this
      pReg.elName=toSignal([@__pipeName,'_'+name].join('.'))
      @__pipe[name]=packEl('reg',pReg)
      @__pipeNewRegs.push(pReg.elName)
    else if _.isPlainObject(obj)
      name=Object.keys(obj)[0]
      width=obj[name]
      pReg=Reg.create(Number(width))
      pReg.cell=this
      pReg.elName=toSignal([@__pipeName,'_'+name].join('.'))
      @__pipe[name]=packEl('reg',pReg)
      @__pipeNewRegs.push(pReg.elName)
    return (block)=>
      pReg.assign(block)

  initial: (list)->
    @__initialList.push list

  verilog: (s)->
    @__regAssignList.push s

  _pipeline: (name_in,opt={},index=0)->
    if _.isString(name_in)
      name=name_in
    else
      name=name_in.getName()
    if index==0
      @__pipeName=name
      @__pipe={}
      @__pipeRegs.push {name:name,opt:opt,pipe:@__pipe}
    return {
      next: (func)=>
        @__regAssignList=[]
        @__pipeNewRegs=[]
        @__pipeAlways(func)
        return @_pipeline(name,null,index+1)
      final: (func)=>
        func(@__pipe)
        @__pipeName=null
    }

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
    if _.isPlainObject(signal)
      return (block)=>
        if _.isFunction(block)
          obj=block()
        else
          obj=block
        list=toFlatten(obj)
        for [path,item] in list
          el=_.get(signal,path)
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
