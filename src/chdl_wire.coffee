CircuitEl=require 'chdl_el'
_ = require 'lodash'
{_expr,packEl,toNumber}=require 'chdl_utils'
{cat} = require 'chdl_operator'
Vnumber = require 'chdl_number'
Expr    = require('chdl_expr')
global= require 'chdl_global'

class Wire extends CircuitEl

  setBindChannel: (c)-> @bindChannel=c
  isBinded: -> @bindChannel?

  @create: (width=1)-> new Wire(width)

  constructor: (width)->
    super()
    @width=width
    @value=0
    @lsb= -1
    @msb= -1
    @states=[]
    @bindChannel=null
    @fieldMap={}
    @local=false
    @clockName=null
    @resetName=null
    @virtual=false
    @share={
      assignBits:{}
      pendingValue:null
    }
    @type=null

  setType: (t)=> @type=t
  getType: => @type

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

  setLocal: => @local=true

  setVirtual: => @virtual=true
  isVirtual: => @virtual

  setGlobal: => @local=false

  init: (v)=>
    @value=v
    return packEl('reg',this)

  pending: (v)=> @share.pendingValue=v

  getPending: => @share.pendingValue ? 0

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

  toList: =>
    list=[]
    for i in [0...@width]
      list.push(@bit(i))
    return list

  bit: (n)->
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
      wire.share=@share
      return packEl('wire',wire)
    else
      wire= Wire.create(toNumber(n)-toNumber(m)+1)
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

  refName: =>
    oomr=''
    if @cell._isGlobal()
      oomr=@cell.getModuleName()+'#'
    if @lsb>=0
      if @width==1
        oomr+@elName+"["+@lsb+"]"
      else
        oomr+@elName+"["+@msb+":"+@lsb+"]"
    else
      oomr+@elName

  get: -> @value

  set: (v)-> @value=v

  getSpace: ->
    if @cell.__indent>0
      indent=@cell.__indent+1
      return Array(indent).join('  ')
    else
      return ''

  pack: -> Expr.start().next(packEl('wire',this))

  drive: (list...)=>
    for i in list
      i.assign(=>_expr(@pack()))

  isAssigned: => not _.isEmpty(@share.assignBits)

  assign: (assignFunc,lineno=-1,self_cell=null)=>
    if self_cell!=null
      cell=self_cell
    else
      cell=@cell

    cell.__assignWaiting=true
    cell.__assignWidth=@width
    if cell.__assignEnv=='always'
      rhs = assignFunc()
      cell.__regAssignList.push ["assign",this,rhs,lineno]
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
      rhs = assignFunc()
      assignItem=["assign",this,rhs,lineno]
      cell.__wireAssignList.push assignItem
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
    cell.__assignWaiting=false

  verilogDeclare: ->
    list=[]
    if @states?
      for i in _.sortBy(@states,(n)=>n.value)
        list.push i.verilogDeclare(true)
    if @width==1
      if @type=='input'
        list.push "wire "+@elName+";"
      else
        list.push "logic "+@elName+";"
    else if @width>1
      if @type=='input'
        list.push "wire ["+(@width-1)+":0] "+@elName+";"
      else
        list.push "logic ["+(@width-1)+":0] "+@elName+";"

    if @virtual
      list.push "initial begin"
      list.push "  #{@elName} = #{Vnumber.hex(@width,@value).refName()};"
      list.push "end"
    return list.join("\n")

  verilogUpdate: -> null

  setWidth:(w)-> @width=w
  getWidth:()=> @width

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
      throw new Error('Set sateMap error')

  isState: (name)=>
    throw new Error(name+' is not valid') unless @stateIsValid(name)
    item = _.find(@states,(i)=> i.label==name)
    return @pack().next('==').next(item)

  notState: (name)=>
    throw new Error(name+' is not valid') unless @stateIsValid(name)
    item = _.find(@states,(i)=> i.label==name)
    return @pack().next('!=').next(item)

  getState: (name)=>
    item = _.find(@states,(i)=> i.label==name)
    return Expr.start().next(item)

  traceDomain: =>

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

module.exports=Wire
