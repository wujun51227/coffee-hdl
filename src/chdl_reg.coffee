CircuitEl = require 'chdl_el'
Wire = require 'chdl_wire'
Expr = require 'chdl_expr'
_ = require 'lodash'
{cat,rhsTraceExpand,_expr,packEl,toNumber}=require 'chdl_utils'
Vnumber = require 'chdl_number'
global  = require('chdl_global')

class Reg extends CircuitEl
  resetMode: 'async' #async or sync
  resetValue: 0

  constructor: (width)->
    super()
    @bindClockName=null
    @resetName=null
    @width=width
    @states=[]
    @lsb= -1
    @msb= -1
    @assertHigh=false
    @negClock=false
    @enableSignal=null
    @enableValue=null
    @clearSignal=null
    @clearValue=null
    @fieldMap={}
    @local=false
    @staticAssign=false
    @share={
      assignList:[]
      alwaysList:null
      pendingValue:null
    }

  isLocal: => @local

  setLocal: => @local=true

  setGlobal: => @local=false

  isVirtual: => false

  init: (v)=>
    @resetValue=v
    return packEl('reg',this)

  clock:(clock)=>
    throw new Error("clock can not be null") if clock==null
    if clock!=''
      if _.isString(clock)
        @bindClockName=clock
      else
        @bindClockName=clock.getName()
    return packEl('reg',this)

  reset:(reset,mode='async',assertValue=false)=>
    if reset==null
      @resetMode=null
      @resetName=null
    else if reset!=''
      if _.isString(reset)
        @resetName=reset
      else
        @resetName=reset.getName()
      @resetMode=mode
      @assertHigh= assertValue
    return packEl('reg',this)

  negedge: =>
    @negClock=true
    return packEl('reg',this)

  syncReset: ()=>
    @resetMode='sync'
    return packEl('reg',this)

  asyncReset: (reset=null)=>
    console.log '=========================='
    console.log 'Deprecated use reset(name,mode,assertValue)'
    console.log '=========================='
    @resetMode='async'
    if _.isString(reset)
      @resetName=reset
    else
      @resetName=reset.getName()
    return packEl('reg',this)

  config: (data)=>
    if data.resetMode?
      @resetMode= data.resetMode
    if data.noReset?
      @resetMode= null
      @resetName=null
    if data.resetName?
      @resetName= data.resetName
    if data.clockName?
      @bindClockName= data.clockName
    if data.resetValue?
      @resetValue= data.resetValue
    if data.negedge?
      @negClock=data.negedge

  pending: (v)=> @share.pendingValue=v

  getPending: => @share.pendingValue ? @elName

  noReset: =>
    console.log '=========================='
    console.log 'Deprecated use reset(null)'
    console.log '=========================='
    @resetMode=null
    @resetName=null
    return packEl('reg',this)

  highReset: =>
    @assertHigh=true
    return packEl('reg',this)

  setLsb: (n)-> @lsb=toNumber(n)

  setMsb: (n)-> @msb=toNumber(n)

  getMsb: (n)=> @msb
  getLsb: (n)=> @lsb

  setField: (name,msb=0,lsb=null)=>
    if _.isString(name)
      if lsb==null
        @fieldMap[name]={msb:msb,lsb:msb}
      else
        @fieldMap[name]={msb:msb,lsb:lsb}
      return packEl('reg',this)
    else if _.isPlainObject(name)
      for k,v of name
        if _.isNumber(v)
          @fieldMap[k]={msb:v,lsb:v}
        else if _.isArray(v)
          @fieldMap[k]={msb:v[0],lsb:v[1]}
      return packEl('reg',this)
    else
      return null

  field: (name,msb,lsb)=>
    item = @fieldMap[name]
    if item?
      msb=item.msb
      lsb=item.lsb
      return @slice(msb,lsb)
    else
      return null

  getClock: =>
    if @bindClockName?
      @bindClockName
    else
      @cell.__defaultClock

  getReset: =>
    if @resetMode?
      if @resetName?
        @resetName
      else
        @cell.__defaultReset
    else
      return null

  toList: =>
    list=[]
    for i in [0...@width]
      list.push(@bit(i))
    return list

  bit: (n)->
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

  fromMsb: (n)=>
    if(n<=@width)
      @slice(@width-1,@width-n)
    else
      throw new Error("Slice width #{n} can not great than #{@width}")

  fromLsb: (n)=>
    if(n<=@width)
      @slice(n-1,0)
    else
      throw new Error("Slice width #{n} can not great than #{@width}")

  slice: (n,m)->
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

  refName: =>
    if @lsb>=0
      if @width==1
        @elName+"["+@lsb+"]"
      else
        @elName+"["+@msb+":"+@lsb+"]"
    else
      @elName

  getDwire: =>
    wire= Wire.create(@width)
    wire.link(@cell,global.getPrefix()+'_'+@hier)
    wire.setLsb(@lsb)
    wire.setMsb(@msb)
    return packEl('wire',wire)

  @create: (width=1)-> new Reg(width)

  verilogDeclare: ->
    list=[]
    if @states?
      for i in _.sortBy(@states,(n)=>n.value)
        list.push i.verilogDeclare()
    if @width==1
      list.push "reg "+@elName+";"
      if @staticAssign
        list.push "wire "+@getDwire().refName()+";"
      else
        list.push "reg "+@getDwire().refName()+";"
    else if @width>1
      list.push "reg ["+(@width-1)+":0] "+@elName+";"
      if @staticAssign
        list.push "wire ["+(@width-1)+":0] "+@getDwire().refName()+";"
      else
        list.push "reg ["+(@width-1)+":0] "+@getDwire().refName()+";"

    return list.join("\n")

  verilogUpdate: ->
    throw new Error("clock can not be null") unless @getClock()
    list=[]
    activeEdge= if @negClock then 'negedge' else 'posedge'
    if @resetMode=='async'
      if @assertHigh
        list.push "always @(#{activeEdge} "+@getClock()+" or posedge "+@getReset()+") begin"
      else
        list.push "always @(#{activeEdge} "+@getClock()+" or negedge "+@getReset()+") begin"
    else
      list.push "always @(#{activeEdge} "+@getClock()+") begin"
    if @getReset()?
      if @assertHigh
        list.push "  if("+@getReset()+") begin"
      else
        list.push "  if(!"+@getReset()+") begin"

      list.push "    "+@elName+" <= #`UDLY "+Vnumber.hex(@width,@resetValue).refName()+";"
      list.push "  end"
      if @clearSignal?
        if _.isString(@clearSignal)
          enableSig=_.get(@cell,@clearSignal)
        else
          enableSig=@clearSignal
        if enableSig?
          #console.log enableSig
          list.push "  else if(#{enableSig.getName()}==#{@clearValue} )  begin"
          list.push "    "+@elName+" <= #`UDLY "+Vnumber.hex(@width,@resetValue).refName()+";"
          list.push "  end"
        else
          throw new Error("cant not find enable signal #{@clearSignal}")
      if @enableSignal?
        if _.isString(@enableSignal)
          enableSig=_.get(@cell,@enableSignal)
        else
          enableSig=@enableSignal
        if enableSig?
          list.push "  else if(#{enableSig.getName()}==#{@enableValue} )  begin"
        else
          throw new Error("cant not find enable signal #{@enableSignal}")
      else
        list.push "  else begin"
      list.push "    "+@elName+" <= #`UDLY #{global.getPrefix()}_"+@elName+";"
      list.push "  end"
    else
      if @enableSignal?
        if _.isString(@enableSignal)
          enableSig=_.get(@cell,@enableSignal)
        else
          enableSig=@enableSignal
        if enableSig?
          list.push "  if(#{enableSig.getName()}==#{@enableValue} )  begin"
          list.push "    "+@elName+" <= #`UDLY #{global.getPrefix()}_"+@elName+";"
          list.push "  end"
        else
          throw new Error("cant not find enable signal #{@enableSignal}")
      else
        list.push "  "+@elName+" <= #`UDLY #{global.getPrefix()}_"+@elName+";"
    list.push "end"
    return list.join("\n")

  getSpace: ->
    if @cell.__indent>0
      indent=@cell.__indent+1
      return Array(indent).join('  ')
    else
      return ''

  pack: -> Expr.start().next(packEl('reg',this))

  drive: (list...)=>
    for i in list
      i.assign(=>_expr(@pack()))

  assign: (assignFunc,lineno=-1)=>
    @cell.__assignWaiting=true
    @cell.__assignWidth=@width
    if @cell.__assignEnv=='always'
      if @staticAssign
        throw new Error("This wire have been static assigned")
      @cell.__regAssignList.push ['assign',this,assignFunc(),lineno]
      @cell.__updateWires.push({type:'reg',name:@hier,inst:this})
    else
      if @staticAssign
        throw new Error("This wire have been static assigned")
      assignItem=["assign",this,assignFunc(),lineno]
      @cell.__wireAssignList.push assignItem
      @share.assignList.push [@lsb,@msb,assignItem[2]]
      @staticAssign=true
    @cell.__assignWaiting=false

  stateIsValid: (name)->
    for i in @states
      if name==i.label
        return true
    return false

  stateDef: (arg)=>
    @states=[] if @states==null
    if _.isArray(arg)
      for i,index in arg
        @states.push @cell._const(index,{el:this,label:i})
    else if _.isPlainObject(arg)
      for k,v of arg
        @states.push @cell._const(v,{el:this,label:k})
    else
      throw new Error("Set sateMap error "+JSON.stringify(arg))

  nextStateIs: (name)=>
    throw new Error(name+' is not valid') unless @stateIsValid(name)
    item = _.find(@states,(i)=> i.label==name)
    Expr.start().next(@getDwire()).next('==').next(item)

  isState: (name)=>
    throw new Error(name+' is not valid') unless @stateIsValid(name)
    item = _.find(@states,(i)=> i.label==name)
    Expr.start().next(packEl('reg',this)).next('==').next(item)

  isNthState: (n)=>
    item=@states[n]
    Expr.start().next(packEl('reg',this)).next('==').next(item)

  getNthState: (n)=>
    throw new Error("index #{n} is not valid") if n>=@states.length or n<0
    return @states[n]

  isLastState: ()=>
    item=_.last(@states)
    Expr.start().next(packEl('reg',this)).next('==').next(item)

  preSwitch: (prevState,nextState)=>
    throw new Error(prevState+' is not valid') unless @stateIsValid(prevState)
    throw new Error(nextState+' is not valid') unless @stateIsValid(nextState)
    previtem = _.find(@states,(i)=> i.label==prevState)
    nextitem = _.find(@states,(i)=> i.label==nextState)
    Expr.start().next(packEl('reg',this)).next('==').next(previtem).next('&&').next(@getDwire()).next('==').next(nextitem)

  notState: (name)=>
    throw new Error(name+' is not valid') unless @stateIsValid(name)
    item = _.find(@states,(i)=> i.label==name)
    Expr.start().next(packEl('reg',this)).next('!=').next(item)

  setState: (name)=>
    throw new Error(name+'is not valid') unless @stateIsValid(name)
    item = _.find(@states,(i)=> i.label==name)
    expr=_expr Expr.start().next(item)
    @cell.__regAssignList.push ['assign',this,expr,-1]
    @cell.__updateWires.push({type:'reg',name:@hier,inst:this})
	
  getState: (name)=>
    item = _.find(@states,(i)=> i.label==name)
    return Expr.start().next(item)

  stateSwitch: (obj)=>
    @cell.__regAssignList.push ['assign',this,_expr(@pack()),-1]
    for src,list of obj
      @cell.__regAssignList.push ["if",@isState(src),-1]
      for item,index in list
        dst = item.value()
        if index==0
          if item.cond?
            @cell.__regAssignList.push ["if",item.cond,-1]
            @cell.__regAssignList.push ["assign",this, _expr(@getState(dst)),-1]
            @cell.__regAssignList.push ["end",-1]
          else
            @cell.__regAssignList.push ["assign",this,_expr(@getState(dst)),-1]
        else
          if item.cond?
            @cell.__regAssignList.push ["elseif",item.cond,-1]
            @cell.__regAssignList.push ["assign",this,_expr(@getState(dst)),-1]
            @cell.__regAssignList.push ["end",-1]
          else
            @cell.__regAssignList.push ["else",-1]
            @cell.__regAssignList.push ["assign",this,_expr(@getState(dst)),-1]
            @cell.__regAssignList.push ["end",-1]
      @cell.__regAssignList.push ["end",-1]

  getWidth: => @width

  enable: (s,value=1)=>
    @enableSignal=s
    @enableValue=value
    return packEl('reg',this)

  clear: (s,value=1)=>
    @clearSignal=s
    @clearValue=value
    return packEl('reg',this)

  simProperty: ->
    {
      clock: @getClock()
      clockEdge: (if @negClock then 'negedge' else 'posedge')
      reset: @getReset()
      resetAssert: @assertHigh
      resetValue: @resetValue
      clearSignal: @clearSignal
      clearValue: @clearValue
      enableSignal: @enableSignal
      enableValue: @enableValue
    }

  reverse: ()=>
    tempWire=@cell._localWire(@width,'reverse')
    list=[]
    for i in [0...@width]
      list.push @bit(i)
    tempWire.assign((=> cat(list)))
    return tempWire

  select: (cb)=>
    list=[]
    for i in [0...@width]
      index = @width-1-i
      if cb(index)
        list.push @bit(index)
    tempWire=@cell._localWire(list.length,'select')
    tempWire.assign((=> cat(list)))
    return tempWire

module.exports=Reg
