Wire=require 'chdl_wire'
Reg=require 'chdl_reg'
{toSignal,packEl,toNumber}=require 'chdl_utils'
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
    @isVec=false
    @depth=0
    @shadowReg=null
    @isRegConfig={}
    @bindChannel=null
    @bindSignal=null
    @bindClock=null

    @isClock=false
    @isReset=false

  getSpace: ->
    if @cell.__indent>0
      indent=@cell.__indent+1
      return Array(indent).join('  ')
    else
      return ''

  pending: (v)=>
    if @isReg
      @shadowReg.pending(v)
    else
      @share.pendingValue=v

  getPending: =>
    if @isReg
      @shadowReg.getPending()
    else
      @share.pendingValue ? 0

  asClock: =>
    @isClock=true
    return packEl('port',this)

  asReset: =>
    @isReset=true
    return packEl('port',this)

  domain: (clockName)=>
    @bindClock=clockName
    return packEl('port',this)

  toList: =>
    list=[]
    for i in [0...@width]
      list.push(@bit(i))
    return list

  bit: (n)->
    if @width==1 and n==0
      if @lsb==-1 or @lsb==0
        return packEl('port',this)
      else
        throw new Error("bit select error")
    if @isReg
      @shadowReg.bit(n)
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

  slice: (n,m)=>
    if @isReg
      @shadowReg.slice(n,m)
    else
      if n.constructor.name=='Expr'
        width=toNumber(n.str)-toNumber(m.str)+1
        if width==@width
          return packEl('wire',this)
        wire= Wire.create(width)
        wire.link(@cell,@hier)
        wire.setLsb(m.str)
        wire.setMsb(n.str)
        wire.share=@share
        return packEl('wire',wire)
      else
        width=toNumber(n)-toNumber(m)+1
        if width==@width
          return packEl('wire',this)
        wire= Wire.create(width)
        wire.link(@cell,@hier)
        wire.setLsb(m)
        wire.setMsb(n)
        wire.share=@share
        return packEl('wire',wire)

  ext: (n)=>
    wire= Wire.create(@width+n)
    wire.link(@cell,@hier)
    wire.setLsb(@msb)
    wire.setMsb(@lsb)
    wire.share=@share
    return packEl('wire',wire)

  assign: (assignFunc,lineno)=>
    @cell.__assignWaiting=true
    @cell.__assignWidth=@width
    if @cell.__assignEnv=='always'
      if !@isReg
        rhs = assignFunc()
        @cell.__regAssignList.push ["assign",this,rhs,-1]
        if @lsb==-1
          for i in _.range(@width)
            if @share.assignBits[i]
              throw new Error("This wire have been assigned again #{@elName}")
            else
              @share.assignBits[i]=0
        else
          for i in [@lsb..@msb]
            if @share.assignBits[i]
              throw new Error("This wire have been assigned again #{@elName}")
            else
              @share.assignBits[i]=0
      else
        @shadowReg.assign(assignFunc,lineno)
    else
      rhs = assignFunc()
      assignItem=["assign",this,rhs,lineno]
      @cell.__wireAssignList.push assignItem
      if @lsb==-1
        for i in _.range(@width)
          if @share.assignBits[i]?
            throw new Error("This wire have been assigned again #{@elName}")
          else
            @share.assignBits[i]=1
      else
        for i in [@lsb..@msb]
          if @share.assignBits[i]?
            throw new Error("This wire have been assigned again #{@elName}")
          else
            @share.assignBits[i]=1
    @cell.__assignWaiting=false

  asReg: (config={})=>
    if @type=='output'
      @isReg=true
      @isRegConfig=config
    else
      throw new Error('Only output port can be treat as a register')
    return packEl('port',this)

  asVec: (depth)=>
    if @type=='output'
      @isVec=true
      @depth=depth
    else
      throw new Error('Only output port can be treat as a register')
    return packEl('port',this)

  portDeclare: ->
    if @type=='input'
      if @width==1
        "input "+toSignal(@elName)
      else
        "input ["+(@width-1)+":0] "+toSignal(@elName)
    else if @type=='output'
      if @width==1
        if @isVec
          "output "+@elName+"[0:#{@depth-1}]"
        else
          "output "+@elName
      else
        if @isVec
          "output ["+(@width-1)+":0] "+@elName+"[0:#{@depth-1}]"
        else
          "output ["+(@width-1)+":0] "+@elName

  setShadowReg: (i)=> @shadowReg = i

  isRegType: => @isReg

module.exports=Port
