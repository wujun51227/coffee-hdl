CircuitEl = require 'chdl_el'
Wire = require 'chdl_wire'
_ = require 'lodash'
{packEl,toSignal,toFlatten} = require 'chdl_utils'
global = require 'chdl_global'

class Channel extends CircuitEl

  constructor: (path=null)->
    super()
    @bindPortPath=null
    @portMap={}
    @wireMap=null
    @portList= []
    @monitor=false
    @probeChannel=path ? null
    global.setId(@uuid,this)

  @create: (path)-> new Channel(path)

  setMonitor: ->
    @monitor=true
    return this

  isMonitor: -> @monitor

  #getWidth: ->
  #  ret=0
  #  for i in @portList
  #    ret+=i.port.width
  #  return ret

  verilogDeclare: ->
    return '' if @portList.length==0
    list=[]
    cache={}
    for line in @portList
      #for [k,v] in toFlatten(line.cell.__ports)
      #  console.log '+++++++++++',k,v.width
      port=line.port
      sigName=toSignal(line.pin)
      if not cache[sigName]?
        cache[sigName]=true
        if not _.get(@cell.__wires,sigName)
          @cell._addWire(sigName,port.width)
    return list.join("\n")

  bindPort: (moduleInst,bindPortPath)->
    if @probeChannel?
      throw new Error('This channel has been aliased '+@probeChannel)
    else
      if @portList.length>0
        portBundle=_.get(moduleInst.__ports,bindPortPath)
        list=toFlatten(portBundle,null,bindPortPath)
        for [portPath,port] in list
          pathList=_.toPath(bindPortPath)
          pinPath=_.toPath(portPath)
          node=pinPath[pathList.length..]
          pinPath.splice(0,pathList.length,@elName)
          hit=_.find(@portList,{node:node,path:portPath,pin:pinPath.join('.')})
          unless hit?
            throw new Error('Channel connect directly miss match '+node)
      else
        portBundle=_.get(moduleInst.__ports,bindPortPath)
        @bindPortPath=bindPortPath
        list=toFlatten(portBundle,null,bindPortPath)
        for [portPath,port] in list
          pathList=_.toPath(bindPortPath)
          pinPath=_.toPath(portPath)
          #pinPath[0]=@elName
          node=pinPath[pathList.length..]
          pinPath.splice(0,pathList.length,@elName)
          @portList.push {port:port,node:node,path:portPath,cell:moduleInst,pin:pinPath.join('.')}

  getPortList: => @portList

  wireList: ->
    out=[]
    for i in @portList
      port=_.get(i.cell,i.path)
      width=port.getWidth()
      wire=Wire.create(width)
      wire.link(@cell,toSignal(@elName+'.'+i.node.join('.')))
      out.push {net:packEl('wire',wire),dir:port.getType(),path:i.node.join('.')}
    return out

  signal: (path)->
    if path?.constructor.name=='Expr'
      result=_.find(@portList,(i)=>
        i.path==@bindPortPath+'.'+path.str
      )
      width=_.get(result.cell,result.path).getWidth()
      wire=Wire.create(width)
      wire.link(@cell,toSignal(@elName+'.'+path.str))
      return packEl('wire',wire)
    else if _.isString(path)
      #console.log '++++',path,@portList
      result=_.find(@portList,(i)=>
        i.path==@bindPortPath+'.'+path
      )
      width=_.get(result.cell,result.path).getWidth()
      wire=Wire.create(width)
      wire.link(@cell,toSignal(@elName+'.'+path))
      return packEl('wire',wire)
    else if path==null
      result=_.find(@portList,(i)=> i.path==@bindPortPath)
      #console.log @portList,@bindPortPath
      width=_.get(result.cell,result.path).getWidth()
      wire=Wire.create(width)
      wire.link(@cell,toSignal(@elName))
      return packEl('wire',wire)

  setPortMap:(k,v)=>
    _.set(@portMap,k,v)

  setWireMap:(k)=>
    @wireMap = k
module.exports= Channel
