{packEl}=require './chdl_utils'
_ = require 'lodash'

class Vnumber

  @create: (value,width=32,type='hex')->
    new Vnumber(value,width,type)

  @hex: (n,m=null)->
    if m==null
      Vnumber.create(n,0,'hex')
    else
      Vnumber.create(m,n,'hex')

  @dec: (n,m=null)->
    if m==null
      Vnumber.create(n,0,'dec')
    else
      Vnumber.create(m,n,'dec')

  @oct: (n,m=null)->
    if m==null
      Vnumber.create(n,0,'oct')
    else
      Vnumber.create(m,n,'oct')

  @bin: (n,m=null)->
    if m==null
      Vnumber.create(n,0,'bin')
    else
      Vnumber.create(m,n,'bin')

  constructor: (value,width=32,type='hex')->
    # 0x literal value is string type and auto valid width, type depend by prefix
    # hex literal value is number type and width/type defined by args 
    # [width]\h literal value is string type and width/type defined by prefix
    # console.log '>>>>>',value,typeof(value),type,_.isNumber(value),_.isString(value)
    @signed=false
    @show_type=type
    @autoWidth=true
    bInt=null
    if _.isNumber(value) and typeof(value)=='number'
      if value>=2**32
        throw new Error("Integer greater than 2**32 should use BigInt type:0x"+value.toString(16))
      bInt=value.toString(2)
    else if typeof(value)=='bigint'
      bInt=value.toString(2)
    else if _.isString(value)
      bInt=BigInt(value).toString(2)
    else if value.constructor.name=='Vnumber'
      clone_bits=value.getBits()
      bInt=clone_bits.reverse().join('')

    if bInt?
      if width>0
        @width=width
        @autoWidth=false
      else
        @width=bInt.length
      @bits=new Array(@width).fill(0)
      bList=bInt.split('').reverse()
      for i,index in bList
        if index<@width
          @bits[index]=Number(i)
        else if i=='1'
          throw new Error("value bit width greater than request width")

  getBits: => _.clone(@bits)

  isAutoWidth: => @autoWidth

  sign: =>
    @signed = true
    return this

  refName: =>
    out=null
    if @show_type=='bin'
      str= @bits[..].reverse().join('')
      out="#{@width}'b#{str}"
    else if @show_type=='oct'
      str= BigInt('0b'+@bits[..].reverse().join('')).toString(8)
      out="#{@width}'o#{str}"
    else if @show_type=='hex'
      str= BigInt('0b'+@bits[..].reverse().join('')).toString(16)
      out="#{@width}'h#{str}"
    else if @show_type=='dec'
      str= BigInt('0b'+@bits[..].reverse().join('')).toString(10)
      out=str
    else
      throw new Error("Unkown show type")

    if @signed
      return "$signed(#{out})"
    else
      return out

  format: (type) => @show_type=type

  bit: (n)->
    out=Vnumber.create(@bits[n],1)
    return packEl('num',out)

  getWidth:()=> @width

  getNumber: =>
    return BigInt('0b'+@bits[..].reverse().join('')).toString(10)

  setWidth:(w)->
    newBits=new Array(w)
    for i in _.range(w)
      if i<@width
        new_bits[i]=@bits[i]
      else
        new_bits[i]=0
    @width=w
    @bits=newBits
    @autoWidth=false

  slice: (n,m)->
    out=Vnumber.create('0b'+@bits[m..n].reverse().join(''),n-m+1)
    return packEl('num',out)

module.exports=Vnumber

