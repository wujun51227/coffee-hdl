CircuitEl=require 'chdl_el'
_ = require 'lodash'
{rhsTraceExpand,_expr,packEl,toNumber}=require 'chdl_utils'
{cat} = require 'chdl_operator'
Vnumber = require 'chdl_number'

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
    @lsb= -1
    @msb= -1
    @states=[]
    @bindChannel=null
    @fieldMap={}
    @depNames=[]
    @local=false
    @clockName=null
    @resetName=null
    @staticWire=true
    @staticAssign=false
    @virtual=false
    @share={
      assignList:[]
      alwaysList:null
      pendingValue:null
    }
    @type=null

  setType: (t)=> @type=t
  getType: => @type

  unsetStaticWire: => @staticWire=false

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

  refName: =>
    oomr=''
    if @cell._isGlobal()
      oomr=@cell.getModuleName()+'#'
    if @cell.__sim
      if @lsb>=0
        if @width==1
          oomr+@hier+".bit("+@lsb+")"
        else
          oomr+@hier+".slice("+@msb+","+@lsb+")"
      else
        @hier+'.getValue()'
    else
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

  drive: (list...)=>
    for i in list
      i.assign(=>_expr(@refName()))

  isAssigned: => @staticWire==false or @staticAssign

  assign: (assignFunc,lineno=-1,self_cell=null)=>
    if self_cell!=null
      cell=self_cell
    else
      cell=@cell

    cell.__assignWaiting=true
    cell.__assignWidth=@width
    if cell.__assignEnv=='always'
      @staticWire=false
      if @staticAssign
        throw new Error("This wire have been static assigned #{@elName}")
      cell.__regAssignList.push ["assign",this,assignFunc(),lineno]
      cell.__updateWires.push({type:'wire',name:@hier,inst:this})
    else
      if @staticWire==false or @staticAssign
        throw new Error("This wire have been assigned again #{@elName}")
      assignItem=["assign",this,assignFunc(),lineno]
      cell.__wireAssignList.push assignItem
      @share.assignList.push [@lsb,@msb,assignItem[2]]
      @staticAssign=true
    cell.__assignWaiting=false

  getDepNames: => _.uniq(@depNames)

  pushDepNames: (n...)=> @depNames.push(n...)

  verilogDeclare: ->
    list=[]
    if @states?
      for i in _.sortBy(@states,(n)=>n.value)
        list.push "localparam "+@elName+'__'+i.state+"="+i.value+";"
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
    _expr "#{@refName()}==#{@elName+'__'+name}"

  notState: (name)=>
    _expr "#{@refName()}!=#{@elName+'__'+name}"

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

  simList: =>
    if @share.alwaysList?
      list=[]
      transfer=null
      for i in @share.alwaysList
        if i[0]=='if'
          list.push({type:'cond',e:i[1],action:null})
          transfer=_.last(list)
        else if i[0]=='assign'
          if i[1].hier==@hier
            if transfer?
              transfer.action=rhsTraceExpand(@hier,{lsb:i[1].lsb,msb:i[1].msb},i[2])
            else
              list.push(rhsTraceExpand(@hier,{lsb:i[1].lsb,msb:i[1].msb},i[2])...)
        else if i[0]=='elseif'
          list.push({type:'cond',e:i[1],action:null})
          transfer=_.last(list)
        else if i[0]=='else'
          list.push({type:'cond',e:null,action:null})
          transfer=_.last(list)
        else if i[0]=='end'
          list.push({type:'end'})
          transfer=null
      return list
    else
      list=[]
      for i in @share.assignList
        list.push(rhsTraceExpand(@hier,{lsb:i[0],msb:i[1]},i[2])...)
      return list


module.exports=Wire
