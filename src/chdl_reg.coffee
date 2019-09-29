CircuitEl = require 'chdl_el'
ElementSets = require 'chdl_el_sets'
_ = require 'lodash'
{packEl,toNumber,hex}=require 'chdl_utils'

class Reg extends CircuitEl
  value: 0
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
    @isMem=false
    @assertHigh=false
    @enableSignal=null
    @enableValue=null
    @clearSignal=null
    @clearValue=null
    @fieldMap={}
    @needInitial=false
    @depNames=[]
    @local=false
    @staticAssign=false

  setLocal: =>
    @local=true
    return packEl('reg',this)

  setMem: -> @isMem=true

  init: (v,initial=false)=>
    @value=v
    @resetValue=v
    @needInitial=initial
    return packEl('reg',this)

  clock:(clock)=>
    if _.isString(clock)
      @bindClockName=clock
    else
      @bindClockName=clock.getName()
    return packEl('reg',this)

  syncReset: (reset)=>
    @resetMode='sync'
    if _.isString(reset)
      @resetName=reset
    else
      @resetName=reset.getName()
    return packEl('reg',this)

  asyncReset: (reset=null)=>
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

  noReset: =>
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

  bit: (n)->
    reg= Reg.create(1)
    reg.link(@cell,@elName)
    if n.constructor?.name=='Expr'
      reg.setLsb(n.str)
      reg.setMsb(n.str)
      reg.isMem=@isMem
      return packEl('reg',reg)
    else
      reg.setLsb(n)
      reg.setMsb(n)
      reg.isMem=@isMem
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
      reg.link(@cell,@elName)
      reg.setMsb(n.str)
      reg.setLsb(m.str)
      reg.isMem=@isMem
      return packEl('reg',reg)
    else
      reg= Reg.create(toNumber(n)-toNumber(m)+1)
      reg.link(@cell,@elName)
      reg.setMsb(n)
      reg.setLsb(m)
      reg.isMem=@isMem
      return packEl('reg',reg)

  refName: ->
    if @lsb>=0
      if @width==1
        @elName+"["+@lsb+"]"
      else
        @elName+"["+@msb+":"+@lsb+"]"
    else
      @elName

  get: -> @value

  set: (v)-> @value=v

  @create: (width=1)-> new Reg(width)

  verilogDeclare: ->
    list=[]
    if @states?
      for i in _.sortBy(@states,(n)=>n.value)
        list.push "localparam "+@elName+'__'+i.state+" = "+i.value+";"
    if @width==1
      list.push "reg "+@elName+";"
      if @staticAssign
        list.push "wire _"+@elName+";"
      else
        list.push "reg _"+@elName+";"
    else if @width>1
      list.push "reg ["+(@width-1)+":0] "+@elName+";"
      if @staticAssign
        list.push "wire ["+(@width-1)+":0] _"+@elName+";"
      else
        list.push "reg ["+(@width-1)+":0] _"+@elName+";"

    if @needInitial
      list.push "initial begin"
      list.push "  #{@elName} = #{@width}'hx;"
      list.push "  #1"
      list.push "  #{@elName} = #{hex(@width,@resetValue)};"
      list.push "end"
    return list.join("\n")

  verilogUpdate: ->
    list=[]
    if @resetMode=='async'
      if @assertHigh
        list.push "always @(posedge "+@getClock()+" or posedge "+@getReset()+") begin"
      else
        list.push "always @(posedge "+@getClock()+" or negedge "+@getReset()+") begin"
    else
      list.push "always @(posedge "+@getClock()+") begin"
    if @getReset()?
      if @assertHigh
        list.push "  if("+@getReset()+") begin"
      else
        list.push "  if(!"+@getReset()+") begin"

      list.push "    "+@elName+" <= #`UDLY "+@resetValue+";"
      list.push "  end"
      if @clearSignal?
        enableSig=_.get(@cell,@clearSignal)
        if enableSig?
          console.log enableSig
          list.push "  else if(#{enableSig.getName()}==#{@clearValue} )  begin"
          list.push "    "+@elName+" <= #`UDLY "+@resetValue+";"
          list.push "  end"
        else
          throw new Error("cant not find enable signal #{@clearSignal}")
      if @enableSignal?
        enableSig=_.get(@cell,@enableSignal)
        if enableSig?
          list.push "  else if(#{enableSig.getName()}==#{@enableValue} )  begin"
        else
          throw new Error("cant not find enable signal #{@enableSignal}")
      else
        list.push "  else begin"
      list.push "    "+@elName+" <= #`UDLY _"+@elName+";"
      list.push "  end"
    else
      if @enableSignal?
        enableSig=_.get(@cell,@enableSignal)
        if enableSig?
          list.push "  if(#{enableSig.elName}==#{@enableValue} )  begin"
          list.push "    "+@elName+" <= #`UDLY _"+@elName+";"
          list.push "  end"
        else
          throw new Error("cant not find enable signal #{@enableSignal}")
      else
        list.push "  "+@elName+" <= #`UDLY _"+@elName+";"
    list.push "end"
    return list.join("\n")

  getSpace: ->
    if @cell.__indent>0
      indent=@cell.__indent+1
      return Array(indent).join('  ')
    else
      return ''

  assign: (assignFunc)=>
    ElementSets.clear()
    @cell.__assignWaiting=true
    @cell.__assignWidth=@width
    if @isMem
      @cell.__regAssignList.push @getSpace()+"#{@refName()} = #{assignFunc()};"
    else if @cell.__assignEnv=='always'
      if @staticAssign
        throw new Error("This wire have been static assigned")
      @cell.__regAssignList.push @getSpace()+"_#{@refName()} = #{assignFunc()};"
      @cell.__updateWires.push({type:'reg',name:@elName,pending:@elName})
    else
      if @staticAssign
        throw new Error("This wire have been static assigned")
      @cell.__wireAssignList.push "assign _#{@refName()} = #{assignFunc()};"
      @staticAssign=true
    @cell.__assignWaiting=false
    @depNames.push(ElementSets.get()...)

  getDepNames: => _.uniq(@depNames)

  stateIsValid: (name)->
    for i in @states
      if name==i.state
        return true
    return false

  stateDef: (arg)=>
    @states=[] if @states==null
    if _.isArray(arg)
      for i,index in arg
        @states.push {state:i,value:index}
    else if _.isPlainObject(arg)
      for k,v of arg
        @states.push {state:k,value:v}
    else
      throw new Error("Set sateMap error "+JSON.stringify(arg))

  nextStateIs: (name)=>
    throw new Error(name+' is not valid') unless @stateIsValid(name)
    "_#{@refName()}==#{@elName+'__'+name}"

  isState: (name)=>
    throw new Error(name+' is not valid') unless @stateIsValid(name)
    "#{@refName()}==#{@elName+'__'+name}"

  isNthState: (n)=>
    item=@states[n]
    "#{@refName()}==#{@elName+'__'+item.state}"

  isLastState: ()=>
    item=_.last(@states)
    "#{@refName()}==#{@elName+'__'+item.state}"

  preSwitch: (prevState,nextState)=>
    throw new Error(prevState+' is not valid') unless @stateIsValid(prevState)
    throw new Error(nextState+' is not valid') unless @stateIsValid(nextState)
    "((#{@refName()}==#{@elName+'__'+prevState}) && (_#{@refName()}==#{@elName+'__'+nextState}))"

  notState: (name)=>
    throw new Error(name+' is not valid') unless @stateIsValid(name)
    "#{@refName()}!=#{@elName+'__'+name}"

  setState: (name)=>
    throw new Error(name+'is not valid') unless @stateIsValid(name)
    @cell.__regAssignList.push @getSpace()+"_#{@refName()}=#{@elName+'__'+name};"
    @cell.__updateWires.push({type:'reg',name:@elName})
	
  getState: (name)=> @elName+'__'+name

  stateSwitch: (obj)=>
    @cell.__regAssignList.push "_#{@refName()} = #{@elName};"
    for src,v of obj
      for dst,condFunc of v
          @cell.__regAssignList.push "if(#{@refName()}==#{@elName+'__'+src} && #{condFunc()}) begin"
          @cell.__regAssignList.push "  _#{@refName()} = #{@elName+'__'+dst};"
          @cell.__regAssignList.push "end"
  getWidth: => @width

  enable: (s,value=1)=>
    @enableSignal=s
    @enableValue=value
    return packEl('reg',this)

  clear: (s,value=1)=>
    @clearSignal=s
    @clearValue=value
    return packEl('reg',this)

module.exports=Reg
