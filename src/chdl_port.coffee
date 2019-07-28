Wire=require 'chdl_wire'
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
    @reg=null
    @isReg=false
    @isRegConfig={}
    @pendingValue=null
    @bindChannel=null
    @bindSignal=null

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

  assign: (assignFunc)=>
    @cell.__assignWaiting=true
    @cell.__assignWidth=@width
    if @cell.__assignInAlways
      if @staticAssign
        throw new Error("This wire have been static assigned")
      else if @firstCondAssign and !@isReg
        if @width==1
          @cell.__wireAssignList.push "reg _"+@elName+";"
        else
          @cell.__wireAssignList.push "reg ["+(@width-1)+":0] _"+@elName+";"
        @cell.__wireAssignList.push "assign #{@elName} = _#{@elName};"
        @firstCondAssign=false
      @cell.__regAssignList.push @getSpace()+"_#{@refName()} = #{assignFunc()};"
    else
      @cell.__wireAssignList.push "assign #{@refName()} = #{assignFunc()};"
      @staticAssign=true
    @cell.__assignWaiting=false
    @cell.__updateWires.push({type:'wire',name:@elName,pending:@pendingValue})

  fromReg: (name)=>
    if @type=='output'
      @reg=toSignal(name)
    else
      throw new Error('Only output port can be aliased to a register')
    return packEl('port',this)

  asReg: (config={})=>
    if @type=='output'
      @isReg=true
      @isRegConfig=config
    else
      throw new Error('Only output port can be treat as a register')
    return packEl('port',this)

  portDeclare: ->portDeclare(@type,this)

  verilogAssign: ->
    if @reg?
      return "\nassign #{@refName()} = #{@reg};"
    else
      return ''

module.exports=Port
