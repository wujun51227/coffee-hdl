{packEl}=require './chdl_utils'
_ = require 'lodash'

class Vnumber

  @create: (value,width=32,type='hex')->
    new Vnumber(value,width,type)

  constructor: (value,width=32,type='hex')->
    # 0x literal value is string type and auto valid width, type depend by prefix
    # hex literal value is number type and width/type defined by args 
    # [width]\h literal value is string type and width/type defined by prefix
    # console.log '>>>>>',value,typeof(value),type,_.isNumber(value),_.isString(value)
    @signed=false
    @show_type=type
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

  refName: =>
    if @show_type=='bin'
      str= @bits[..].reverse().join('')
      return "#{@width}'b#{str}"
    else if @show_type=='oct'
      str= BigInt('0b'+@bits[..].reverse().join('')).toString(8)
      return "#{@width}'o#{str}"
    else if @show_type=='hex'
      str= BigInt('0b'+@bits[..].reverse().join('')).toString(16)
      return "#{@width}'h#{str}"
    else if @show_type=='dec'
      str= BigInt('0b'+@bits[..].reverse().join('')).toString(10)
      return str
    else
      throw new Error("Unkown show type")

  format: (type) => @show_type=type

  bit: (n)->
    out=Vnumber.create(@bits[n],1)
    return packEl('num',out)

  getWidth:()=> @width

  setWidth:(w)->
    newBits=new Array(w)
    for i in _.range(w)
      if i<@width
        new_bits[i]=@bits[i]
      else
        new_bits[i]=0
    @width=w
    @bits=newBits

  slice: (n,m)->
    out=Vnumber.create('0b'+@bits[m..n].reverse().join(''),n-m+1)
    return packEl('num',out)

module.exports=Vnumber

