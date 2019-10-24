Wire=require 'chdl_wire'
ElementSets = require 'chdl_el_sets'
{toSignal,portDeclare,packEl}=require 'chdl_utils'
_ = require 'lodash'

class Port extends Wire

  @in: (width=1)->
    port=new Port('input',width)
    return port

  @out: (width=1)->
    port=new Port('output',width)
    return port

  @bind: (channel_name)->
    port=new Port(null,0)
    port.setBindChannel(channel_name)
    return port

  setType: (t)=> @type=t
  getType: => @type
  setBindChannel: (c)=> @bindChannel=c
  setBindSignal: (c)=> @bindSignal=c
  isBinded: => @bindChannel? or @bindSignal?

 #   ret={}
 #   list=toFlatten(@cell[channel_name])
 #   for [portPath,port] in list
 #     if port.type=='output'
 #       _.set(ret,portPath,new Port('output',port.width))
 #     else if port.type=='input'
 #       _.set(ret,portPath,new Port('input',port.width)
 #   console.log '>>>>',ret
 #   return ret

  constructor: (type,width)->
    super(width)
    @type=type
    @isReg=false
    @shadowReg=null
    @isRegConfig={}
    @pendingValue=null
    @bindChannel=null
    @bindSignal=null
    @depNames=[]

    @isClock=false
    @isReset=false

  getSpace: ->
    if @cell.__indent>0
      indent=@cell.__indent+1
      return Array(indent).join('  ')
    else
      return ''

  asClock: =>
    @isClock=true
    return packEl('port',this)

  asReset: =>
    @isReset=true
    return packEl('port',this)

  assign: (assignFunc,lineno)=>
    @cell.__assignWaiting=true
    @cell.__assignWidth=@width
    ElementSets.clear()
    if @cell.__assignEnv=='always'
      if !@isReg
        @share.staticWire=false
        if @share.staticAssign
          throw new Error("This wire have been static assigned")
        @cell.__regAssignList.push ["assign","#{@refName()}",assignFunc(),-1]
        @cell.__updateWires.push({type:'wire',name:@elName,pending:@pendingValue})
      else
        @shadowReg.assign(assignFunc,lineno)
    else
      if @share.staticWire==false or @share.staticAssign
        throw new Error("This wire have been assigned again")
      @cell.__wireAssignList.push ["assign", "#{@refName()}",assignFunc(),lineno]
      @share.staticAssign=true
    @cell.__assignWaiting=false
    @depNames.push(ElementSets.get()...)

  getDepNames: => _.uniq(@depNames)

  asReg: (config={})=>
    if @type=='output'
      @isReg=true
      @isRegConfig=config
    else
      throw new Error('Only output port can be treat as a register')
    return packEl('port',this)

  portDeclare: ->portDeclare(@type,this)

  setShadowReg: (i)=> @shadowReg = i

module.exports=Port
