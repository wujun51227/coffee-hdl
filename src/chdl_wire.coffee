CircuitEl=require 'chdl_el'
ElementSets = require 'chdl_el_sets'
_ = require 'lodash'
{_expr,packEl,toNumber,cat}=require 'chdl_utils'

class Wire extends CircuitEl
  width: 0

  @bind: (channel_name)->
    wire=new Wire(0)
    wire.setBindChannel(channel_name)
    return wire

  setBindChannel: (c)-> @bindChannel=c
  isBinded: -> @bindChannel?

  @create: (width=1)-> new Wire(width)

  constructor: (width)->
    super()
    @width=width
    @value=0
    @pendingValue=null
    @lsb= -1
    @msb= -1
    @states=[]
    @bindChannel=null
    @fieldMap={}
    @depNames=[]
    @local=false
    @clockName=null
    @resetName=null
    @share={
      staticWire:true
      staticAssign:false
    }

  attach:(clock,reset)=>
    if _.isString(clock)
      @clockName=clock
    else
      @clockName=clock.getName()

    if _.isString(reset)
      @resetName=reset
    else
      @resetName=reset.getName()

    return packEl('wire',this)

  getClock: =>
    if @clockName?
      @clockName
    else
      null

  getReset: =>
    if @resetName?
      @resetName
    else
      null

  setLocal: =>
    @local=true
    return packEl('wire',this)

  init: (v)->
    @value=v
    return this

  defaultValue: (v)=>
    @pendingValue=v
    return packEl('wire',this)

  setField: (name,msb=0,lsb=null)=>
    if _.isString(name)
      if lsb==null
        @fieldMap[name]={msb:msb,lsb:msb}
      else
        @fieldMap[name]={msb:msb,lsb:lsb}
      return packEl('wire',this)
    else if _.isPlainObject(name)
      for k,v of name
        if _.isNumber(v)
          @fieldMap[k]={msb:v,lsb:v}
        else if _.isArray(v)
          @fieldMap[k]={msb:v[0],lsb:v[1]}
      return packEl('wire',this)
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

  setLsb: (n)-> @lsb=toNumber(n)
  setMsb: (n)-> @msb=toNumber(n)

  getMsb: (n)=> @msb
  getLsb: (n)=> @lsb

  bit: (n)->
    wire= Wire.create(1)
    wire.link(@cell,@hier)
    if n.constructor.name=='Expr'
      wire.setLsb(n.str)
      wire.setMsb(n.str)
      return packEl('wire',wire)
    else
      wire.setLsb(n)
      wire.setMsb(n)
      return packEl('wire',wire)

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
    if n.constructor.name=='Expr'
      wire= Wire.create(toNumber(n.str)-toNumber(m.str)+1)
      wire.link(@cell,@hier)
      wire.setLsb(m.str)
      wire.setMsb(n.str)
      return packEl('wire',wire)
    else
      wire= Wire.create(toNumber(n)-toNumber(m)+1)
      wire.link(@cell,@hier)
      wire.setLsb(m)
      wire.setMsb(n)
      return packEl('wire',wire)

  refName: =>
    if @lsb>=0
      if @width==1
        @elName+"["+@lsb+"]"
      else
        @elName+"["+@msb+":"+@lsb+"]"
    else
      @elName

  get: -> @value

  set: (v)-> @value=v

  getSpace: ->
    if @cell.__indent>0
      indent=@cell.__indent+1
      return Array(indent).join('  ')
    else
      return ''

  assign: (assignFunc,lineno=-1)=>
    @cell.__assignWaiting=true
    @cell.__assignWidth=@width
    ElementSets.clear()
    if @cell.__assignEnv=='always'
      @share.staticWire=false
      if @share.staticAssign
        throw new Error("This wire have been static assigned")
      @cell.__regAssignList.push ["assign",this,assignFunc(),lineno]
      @cell.__updateWires.push({type:'wire',name:@hier,pending:@pendingValue,inst:this})
    else
      if @share.staticWire==false or @share.staticAssign
        throw new Error("This wire have been assigned again")
      @cell.__wireAssignList.push ["assign",this,assignFunc(),lineno]
      @share.staticAssign=true
    @cell.__assignWaiting=false
    @depNames.push(ElementSets.get()...)

  getDepNames: => _.uniq(@depNames)

  pushDepNames: (n...)=> @depNames.push(n...)

  verilogDeclare: ->
    list=[]
    if @states?
      for i in _.sortBy(@states,(n)=>n.value)
        list.push "localparam "+@elName+'__'+i.state+"="+i.value+";"
    if @width==1
      if @share.staticWire
        list.push "wire "+@elName+";"
      else
        list.push "reg "+@elName+";"
    else if @width>1
      if @share.staticWire
        list.push "wire ["+(@width-1)+":0] "+@elName+";"
      else
        list.push "reg ["+(@width-1)+":0] "+@elName+";"
    return list.join("\n")

  setWidth:(w)-> @width=w
  getWidth:()=> @width

  stateDef: (arg)=>
    @states=[] if @states==null
    if _.isArray(arg)
      for i,index in arg
        @states.push {state:i,value:index}
    else if _.isPlainObject(arg)
      for k,v of arg
        @states.push {state:k,value:v}
    else
      throw new Error('Set sateMap error')

  isState: (name)=>
    _expr "#{@elName}==#{@elName+'__'+name}"

  notState: (name)=>
    _expr "#{@elName}!=#{@elName+'__'+name}"

  getState: (name)=> @elName+'__'+name

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

module.exports=Wire
