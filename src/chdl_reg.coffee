CircuitEl = require 'chdl_el'
Wire = require 'chdl_wire'
Expr = require 'chdl_expr'
_ = require 'lodash'
{_expr,packEl,toNumber}=require 'chdl_utils'
{cat} = require 'chdl_operator'
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
    @addr=null
    @assertHigh=false
    @negClock=false
    @enableSignal=null
    @enableValue=null
    @clearSignal=null
    @clearValue=null
    @stallSignal=null
    @stallValue=null
    @fieldList={}
    @local=false
    @signed=false
    @share={
      assignBits:{}
      pendingValue:null
    }
    global.setId(@uuid,this)

  isLocal: => @local

  setLocal: => @local=true

  setGlobal: => @local=false

  isVirtual: => false

  setAddr: (addr)=>
    @addr=addr
    return packEl('reg',this)

  getAddr: => @addr

  hasAddr: =>
    return @add!=null

  init: (v)=>
    if v?
      if v<0
        @resetValue=Vnumber.hex(@width,2n**BigInt(@width)+BigInt(v))
      else
        @resetValue=v
    else
      @resetValue=0
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

  setSign: =>
    @signed=true
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
      console.log '=========================='
      console.log 'Deprecated, use syncReset/asyncReset:true'
      console.log '=========================='
    if data.resetName?
      console.log '=========================='
      console.log 'Deprecated, use reset:name'
      console.log '=========================='
    if data.clockName?
      console.log '=========================='
      console.log 'Deprecated, use clock:name'
      console.log '=========================='
    if data.resetValue?
      console.log '=========================='
      console.log 'Deprecated, use init:value'
      console.log '=========================='
    if data.noReset?
      console.log '=========================='
      console.log 'Deprecated, use reset:null'
      console.log '=========================='

    if data.asyncReset?
      @resetMode='async'
    if data.syncReset?
      @resetMode='sync'

    if data.reset?
      @resetName= data.reset
    else if data.reset==null
      @resetMode= null
      @resetName=null

    if data.clock?
      @bindClockName= data.clock
    if data.init?
      @resetValue= data.init
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
      [fieldName,desc]=name.split(/::/)
      fieldDesc = desc ? 'None'
      if lsb==null
        @fieldList.push {name:fieldName,msb:msb,lsb:msb,desc:fieldDesc}
      else
        @fieldList.push {name:fieldName,msb:msb,lsb:lsb,desc:fieldDesc}
      return packEl('reg',this)
    else if _.isPlainObject(name)
      for k,v of name
        [fieldName,desc]=k.split(/::/)
        fieldDesc = desc ? 'None'
        if _.isNumber(v)
          @fieldList.push {name:fieldName,msb:v,lsb:v,desc:fieldDesc}
        else if _.isArray(v)
          @fieldList.push {name:fieldName,msb:v[0],lsb:v[1],desc:fieldDesc}
      return packEl('reg',this)
    else
      return null

  field: (name)=>
    item = _.find(@fieldList,{name:name})
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
    if @width==1 and n==0
      if @lsb==-1 or @lsb==0
        return packEl('reg',this)
      else
        throw new Error("bit select error")
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
    if(Math.abs(n)<=@width)
      if n<=0
        if @lsb==-1
          @slice(@width-1,-n)
        else
          @slice(@msb,@lsb-n)
      else
        if @lsb==-1
          @slice(@width-1,@width-n)
        else
          @slice(@msb,@msb-n+1)
    else
      throw new Error("Slice width #{n} can not great than #{@width}")

  fromLsb: (n)=>
    if(Math.abs(n)<=@width)
      if n<=0
        if @lsb==-1
          @slice(@width-1+n,0)
        else
          @slice(@msb+n,@lsb)
      else
        if @lsb==-1
          @slice(n-1,0)
        else
          @slice(@lsb+n-1,@lsb)
    else
      throw new Error("Slice width #{n} can not great than #{@width}")

  slice: (n,m)=>
    if n.constructor?.name=='Expr'
      width=toNumber(n.str)-toNumber(m.str)+1
      if width==@width
        return packEl('reg',this)
      reg= Reg.create(width)
      reg.link(@cell,@hier)
      reg.setMsb(n.str)
      reg.setLsb(m.str)
      reg.share=@share
      return packEl('reg',reg)
    else
      width=toNumber(n)-toNumber(m)+1
      if width==@width
        return packEl('reg',this)
      reg= Reg.create(width)
      reg.link(@cell,@hier)
      reg.setMsb(n)
      reg.setLsb(m)
      reg.share=@share
      return packEl('reg',reg)

  ext: (n)=>
    reg= Reg.create(@width+n)
    reg.link(@cell,@hier)
    reg.setLsb(@msb)
    reg.setMsb(@lsb)
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

  next: => @getDwire()

  getDwire: =>
    wire= Wire.create(@width)
    wire.link(@cell,global.getPrefix()+'_'+@hier)
    wire.setLsb(@lsb)
    wire.setMsb(@msb)
    return packEl('wire',wire)

  @create: (width=1)-> new Reg(width)

  isAssigned: =>
    cnt0=0
    cnt1=0
    for key in Object.keys(@share.assignBits)
      if @share.assignBits[key]==0
        cnt0+=1
      if @share.assignBits[key]==1
        cnt1+=1
    if cnt0>0 and cnt1>0
      throw new Error("Find mixed use static and procedure assign to reg '#{@hier}'")
    return cnt1>0

  verilogDeclare: ->
    list=[]
    if @states?
      for i in _.sortBy(@states,(n)=>n.value)
        list.push i.verilogDeclare(true)

    signStr = ''
    if @signed
      signStr = 'signed '
    if @width==1
      list.push "reg #{signStr}"+@elName+";"
      if @isAssigned()
        list.push "wire #{signStr}"+@getDwire().refName()+";"
      else
        list.push "logic #{signStr}"+@getDwire().refName()+";"
    else if @width>1
      list.push "reg #{signStr}["+(@width-1)+":0] "+@elName+";"
      if @isAssigned()
        list.push "wire #{signStr}["+(@width-1)+":0] "+@getDwire().refName()+";"
      else
        list.push "logic #{signStr}["+(@width-1)+":0] "+@getDwire().refName()+";"

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
      if @stallSignal?
        if _.isString(@stallSignal)
          enableSig=_.get(@cell,@stallSignal)
        else
          enableSig=@stallSignal
        if enableSig?
          #console.log enableSig
          list.push "  else if(#{enableSig.getName()}==#{@stallValue} )  begin"
          list.push "    "+@elName+" <= #`UDLY #{global.getPrefix()}_"+@elName+";"
          list.push "  end"
        else
          throw new Error("cant not find enable signal #{@stallSignal}")
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
      @cell.__regAssignList.push ['assign',this,assignFunc(),lineno]
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
      assignItem=["assign",this,assignFunc(),lineno]
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
    Expr.start().next('(').next(@getDwire()).next('==').next(item).next(')')

  isState: (names...)=>
    tmp=Expr.start().next('(')
    if names.length>1
      for name,index in names
        throw new Error(name+' is not valid') unless @stateIsValid(name)
        item=_.find(@states,(i)=> i.label==name)
        if index==0
          tmp=tmp.next('(').next(packEl('reg',this)).next('==').next(item).next(')')
        else
          tmp=tmp.next('||').next('(').next(packEl('reg',this)).next('==').next(item).next(')')
    else if names.length==1
      name = names[0]
      throw new Error(name+' is not valid') unless @stateIsValid(name)
      item=_.find(@states,(i)=> i.label==name)
      tmp=tmp.next(packEl('reg',this)).next('==').next(item)
    tmp.next(')')

  isNthState: (n)=>
    item=@states[n]
    Expr.start().next('(').next(packEl('reg',this)).next('==').next(item).next(')')

  getNthState: (n)=>
    throw new Error("index #{n} is not valid") if n>=@states.length or n<0
    return @states[n]

  isLastState: ()=>
    item=_.last(@states)
    Expr.start().next('(').next(packEl('reg',this)).next('==').next(item).next(')')

  preSwitch: (prevState,nextState)=>
    throw new Error(prevState+' is not valid') unless @stateIsValid(prevState)
    throw new Error(nextState+' is not valid') unless @stateIsValid(nextState)
    previtem = _.find(@states,(i)=> i.label==prevState)
    nextitem = _.find(@states,(i)=> i.label==nextState)
    Expr.start().next('(').next(packEl('reg',this)).next('==').next(previtem).next('&&').next(@getDwire()).next('==').next(nextitem).next(')')

  notState: (name)=>
    throw new Error(name+' is not valid') unless @stateIsValid(name)
    item = _.find(@states,(i)=> i.label==name)
    Expr.start().next('(').next(packEl('reg',this)).next('!=').next(item).next(')')

  setState: (name)=>
    throw new Error(name+'is not valid') unless @stateIsValid(name)
    item = _.find(@states,(i)=> i.label==name)
    expr=_expr Expr.start().next(item)
    @cell.__regAssignList.push ['assign',this,expr,-1]
	
  getState: (name)=>
    item = _.find(@states,(i)=> i.label==name)
    return Expr.start().next(item)

  getWidth: => @width

  enable: (s,value=1)=>
    @enableSignal=s
    @enableValue=value
    return packEl('reg',this)

  clear: (s,value=1)=>
    @clearSignal=s
    @clearValue=value
    return packEl('reg',this)

  stall: (s,value=1)=>
    @stallSignal=s
    @stallValue=value
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
      stallSignal: @stallSignal
      stallValue: @stallValue
      enableSignal: @enableSignal
      enableValue: @enableValue
    }

  reverse: ()=>
    tempWire=@cell._localWire(@width,'reverse')
    list=[]
    for i in [0...@width]
      list.push @bit(i)
    tempWire.assign((=> _expr(Expr.start().next(cat(list)))))
    return tempWire

  select: (cb)=>
    list=[]
    for i in [0...@width]
      index = @width-1-i
      if cb(index)
        list.push @bit(index)
    tempWire=@cell._localWire(list.length,'select')
    tempWire.assign((=> _expr(Expr.start().next(cat(list)))))
    return tempWire

  dumpJson: =>
    retObj = {
      name: @elName
      width: @width
      default: @resetValue
      fields: _.sortBy(@fieldList,['lsb'])
    }

module.exports=Reg
