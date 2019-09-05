CircuitEl = require 'chdl_el'
Wire = require 'chdl_wire'
_ = require 'lodash'
{packEl,toSignal,toFlatten} = require 'chdl_utils'

class Channel extends CircuitEl

  constructor: (path)->
    super()
    @bindPortPath=null
    @portList= []
    @attachPath=null
    if path!=null
      @aliasPath=path
    else
      @aliasPath=null

  @create: (path)-> new Channel(path)

  #getWidth: ->
  #  ret=0
  #  for i in @portList
  #    ret+=i.port.width
  #  return ret

  getPort: (cell,path)->
    for [name,port] in toFlatten(cell.__ports)
      return port if _.isEqual(_.toPath(name),_.toPath(path))
    return null

  verilogDeclare: ->
    return '' if @portList.length==0
    list=[]
    cache={}
    for line in @portList
      #for [k,v] in toFlatten(line.cell.__ports)
      #  console.log '+++++++++++',k,v.width
      port=@getPort(line.cell,line.path)
      sigName=toSignal(line.pin)
      if not cache[sigName]?
        cache[sigName]=true
        if not _.get(@cell.__wires,sigName)
          if port.width==1
            list.push 'wire '+sigName+';'
          else if port.width>1
            list.push 'wire ['+(port.width-1)+':0] '+sigName+';'
          else
            throw new Error('Channel width unkown')
    return list.join("\n")

  attach: (parent,path)->
    @attachPath={parent,path}

  bindPort: (moduleInst,bindPortPath)->
    if @aliasPath?
      throw new Error('This channel has been aliased '+@aliasPath)
    else
      portBundle=_.get(moduleInst.__ports,bindPortPath)
      @bindPortPath=bindPortPath
      list=toFlatten(portBundle,bindPortPath)
      for [portPath,port] in list
        pathList=_.toPath(bindPortPath)
        pinPath=_.toPath(portPath)
        #pinPath[0]=@elName
        node=pinPath[pathList.length..]
        pinPath.splice(0,pathList.length,@elName)
        @portList.push {node:node,path:portPath,cell:moduleInst,pin:pinPath.join('.')}

  signal: (path)->
    if path?.constructor.name=='Expr'
      result=_.find(@portList,(i)=>
        i.path==@bindPortPath+'.'+path.str
      )
      width=_.get(result.cell,result.path).getWidth()
      wire=Wire.create(width)
      wire.link(@cell,@elName+'__'+path.str)
      return packEl('wire',wire)
    else if _.isString(path)
      #console.log '++++',path,@portList
      result=_.find(@portList,(i)=>
        i.path==@bindPortPath+'.'+path
      )
      width=_.get(result.cell,result.path).getWidth()
      wire=Wire.create(width)
      wire.link(@cell,@elName+'__'+path)
      return packEl('wire',wire)
    else if path==null
      result=_.find(@portList,(i)=> i.path==@bindPortPath)
      #console.log @portList,@bindPortPath
      width=_.get(result.cell,result.path).getWidth()
      wire=Wire.create(width)
      wire.link(@cell,@elName)
      return packEl('wire',wire)

  getWire: (path=null)=>
    if @bindPortPath?
      return @signal(path)
    else if @aliasPath?
      wireName=@elName+'.'+path
      for [name,wireEl] in toFlatten(@cell.__wires)
        #console.log 'get wire',name,wireName
        if wireName==name
          return wireEl
      throw new Error('Can not find aliasPath wire:'+@elName+' '+path)
    else
      throw new Error('Channel should bind to a port')

module.exports= Channel
