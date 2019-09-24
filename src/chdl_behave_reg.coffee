CircuitEl = require 'chdl_el'
Reg = require 'chdl_reg'
_ = require 'lodash'
{packEl,toNumber}=require 'chdl_utils'

class BehaveReg extends Reg
  value: 0
  resetValue:0

  constructor: (width)->
    super()
    @width=width
    @lsb= -1
    @msb= -1
    @fieldMap={}

  @create: (width=1)-> new BehaveReg(width)

  init: (v)=>
    @value=v
    @resetValue=v
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

  bit: (n)->
    reg= new BehaveReg(1)
    reg.link(@cell,@elName)
    if n.constructor?.name=='Expr'
      reg.setLsb(n.str)
      reg.setMsb(n.str)
      return packEl('reg',reg)
    else
      reg.setLsb(n)
      reg.setMsb(n)
      return packEl('reg',reg)

  slice: (n,m)->
    if n.constructor?.name=='Expr'
      reg= new BehaveReg(toNumber(n.str)-toNumber(m.str)+1)
      reg.link(@cell,@elName)
      reg.setMsb(n.str)
      reg.setLsb(m.str)
      return packEl('reg',reg)
    else
      reg= new BehaveReg(toNumber(n)-toNumber(m)+1)
      reg.link(@cell,@elName)
      reg.setMsb(n)
      reg.setLsb(m)
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

  verilogDeclare: (pipe=false)->
    list=[]
    if @width==1
      list.push "reg "+@elName+";"
    else if @width>1
      list.push "reg ["+(@width-1)+":0] "+@elName+";"
    list.push "initial begin"
    list.push "  #{@elName} = #{hex(@width,@resetValue)};"
    list.push "end"
    return list.join("\n")

  verilogUpdate: ->

  delay: (delay=0)=>
    return (assignFunc) =>
      @cell.__assignWidth=@width
      if delay==0
        @cell.__pureAlwaysList.push "  #{@elName} = #{assignFunc()};"
      else
        @cell.__pureAlwaysList.push "  ##{delay} #{@elName} = #{assignFunc()};"

module.exports=BehaveReg
