Wire=require 'chdl_wire'
Reg=require 'chdl_reg'
{toSignal,portDeclare,packEl,toNumber}=require 'chdl_utils'
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

  bit: (n)->
    if @isReg
      reg= Reg.create(1)
      reg.link(@cell,@hier)
      if n.constructor?.name=='Expr'
        reg.setLsb(n.str)
        reg.setMsb(n.str)
        reg.share=@share
        return packEl('reg',reg)
      else
        reg.setLsb(n)
        reg.setMsb(n)
        reg.share=@share
        return packEl('reg',reg)
    else
      wire= Wire.create(1)
      wire.link(@cell,@hier)
      if n.constructor.name=='Expr'
        wire.setLsb(n.str)
        wire.setMsb(n.str)
        wire.share=@share
        return packEl('wire',wire)
      else
        wire.setLsb(n)
        wire.setMsb(n)
        wire.share=@share
        return packEl('wire',wire)

  slice: (n,m)->
    if @isReg
      if n.constructor?.name=='Expr'
        reg= Reg.create(toNumber(n.str)-toNumber(m.str)+1)
        reg.link(@cell,@hier)
        reg.setMsb(n.str)
        reg.setLsb(m.str)
        reg.share=@share
        return packEl('reg',reg)
      else
        reg= Reg.create(toNumber(n)-toNumber(m)+1)
        reg.link(@cell,@hier)
        reg.setMsb(n)
        reg.setLsb(m)
        reg.share=@share
        return packEl('reg',reg)
    else
      if n.constructor.name=='Expr'
        wire= Wire.create(toNumber(n.str)-toNumber(m.str)+1)
        wire.link(@cell,@hier)
        wire.setLsb(m.str)
        wire.setMsb(n.str)
        wire.share=@share
        return packEl('wire',wire)
      else
        wire= Wire.create(toNumber(n)-toNumber(m)+1)
        wire.link(@cell,@hier)
        wire.setLsb(m)
        wire.setMsb(n)
        wire.share=@share
        return packEl('wire',wire)

  assign: (assignFunc,lineno)=>
    @cell.__assignWaiting=true
    @cell.__assignWidth=@width
    if @cell.__assignEnv=='always'
      if !@isReg
        @staticWire=false
        if @staticAssign
          throw new Error("This wire have been static assigned")
        @cell.__regAssignList.push ["assign",this,assignFunc(),-1]
        @cell.__updateWires.push({type:'wire',name:@hier,pending:@pendingValue,inst:this})
      else
        @shadowReg.assign(assignFunc,lineno)
    else
      if @staticWire==false or @staticAssign
        throw new Error("This wire have been assigned again")
      assignItem=["assign",this,assignFunc(),lineno]
      @cell.__wireAssignList.push assignItem
      @share.assignList.push [@lsb,@msb,assignItem[2]]
      @staticAssign=true
    @cell.__assignWaiting=false

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
