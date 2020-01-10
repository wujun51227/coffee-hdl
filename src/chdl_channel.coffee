CircuitEl = require 'chdl_el'
Wire = require 'chdl_wire'
_ = require 'lodash'
{packEl,toSignal,toFlatten} = require 'chdl_utils'

class Channel extends CircuitEl

  constructor: (path)->
    super()
    @bindPortPath=null
    @Port={}
    @portList= []
    @__type='channel'
    if path!=null
      @probeChannel=path
    else
      @probeChannel=null

  @create: (path)-> new Channel(path)

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
          if port.width==1
            list.push 'logic '+sigName+';'
          else if port.width>1
            list.push 'logic ['+(port.width-1)+':0] '+sigName+';'
          else
            throw new Error('Channel width unkown')
    return list.join("\n")

  bindPort: (moduleInst,bindPortPath)->
    if @probeChannel?
      throw new Error('This channel has been aliased '+@probeChannel)
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

  getWire: (path=null)=>
    if @bindPortPath?
      return @signal(path)
    else if @probeChannel?
      wireName=@elName+'.'+path
      for [name,wireEl] in toFlatten(@cell.__wires)
        #console.log 'get wire',name,wireName
        if wireName==name
          return wireEl
      throw new Error('Can not find probeChannel wire:'+@elName+' '+path)
    else
      throw new Error('Channel should bind to a port')

module.exports= Channel
