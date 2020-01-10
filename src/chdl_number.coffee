{packEl}=require './chdl_utils'
_ = require 'lodash'

class Vnumber

  @create: (value,width=32,type='hex')->
    new Vnumber(value,width,type)

  constructor: (value,width=32,type='hex')->
    # 0x literal value is string type and width fixed to 32, type depend by prefix
    # hex literal value is number type and width/type defined by args 
    # 0x\h literal value is string type and width/type defined by prefix
    console.log '>>>>>',value,type,_.isNumber(value),_.isString(value)
    @signed=false
    @show_type=type
    @bits=new Array(width).fill(0)
    if _.isNumber(value)
      if value>=2**32 or width>32
        throw new Error("Integer greater than 2**32 should convert to verilog literal")
      for i in _.range(width)
        @bits[i]=(value>>>i)&1
    else if _.isString(value)
      if value.match(/^0x/)
        list=value[2..].split('').reverse()
        tmp_bits=new Array(list.length*4).fill(0)
        for i,index in list
          tmp_bits[index*4]   = Number(i)&1
          tmp_bits[index*4+1] = (Number(i)>>>1)&1
          tmp_bits[index*4+2] = (Number(i)>>>2)&1
          tmp_bits[index*4+3] = (Number(i)>>>3)&1
        for i,index in tmp_bits
          if index<width
            @bits[index]=i
          else if i==1
            throw new Error("value bit width greater than request width")
      else if value.match(/^0o/)
        list=value[2..].split('').reverse()
        tmp_bits=new Array(list.length*3).fill(0)
        for i,index in list
          tmp_bits[index*3]   = Number(i)&1
          tmp_bits[index*3+1] = (Number(i)>>>1)&1
          tmp_bits[index*3+2] = (Number(i)>>>2)&1

        for i,index in tmp_bits
          if index<width
            @bits[index]=i
          else if i==1
            throw new Error("value bit width greater than request width")

      else if value.match(/^0b/)
        list=value[2..].split('').reverse()
        for i,index in list
          if index<width
            @bits[index]=Number(i)
          else if i=='1'
            throw new Error("value bit width greater than request width")
      else if value.length<=10
        num=Number(value)
        if num>=2**32
          throw new Error("dec format value can not greater than 4G")
        for i in _.range(32)
          @bits[i]=(num>>>i)&1
    else
      clone_bits=value.getBits()
      for i in _.range(width)
        if i < value.getWidth()
          @bits[i]=clone_bits[i]
    @width= width

  getBits: => _.clone(@bits)

  refName: =>
    if @show_type=='bin'
      str=''
      for i in @bits
        str=Number(i)+str
      return "#{@width}'b#{str}"
    else if @show_type=='oct'
      str=''
      i=0
      while i<@width
        s = Number('0b'+@bits[i...(i+3)].reverse().join('')).toString(8)
        str=s+str
        i+=3
      return "#{@width}'o#{str}"
    else if @show_type=='hex'
      str=''
      i=0
      while i<@width
        s = Number('0b'+@bits[i...(i+4)].reverse().join('')).toString(16)
        str=s+str
        i+=4
      return "#{@width}'h#{str}"
    else if @show_type=='dec'
      if @width<=32
        #console.log '>>>>>>',@bits[0...@width].reverse().join('')
        return "#{@width}'d"+Number('0b'+@bits[0...@width].reverse().join('')).toString()
      else
        throw new Error("Only less than 32 bit data can format to dec")
    else
      throw new Error("Unkown show type")

  format: (type) =>
    if type=='dec' and @width>32
      throw new Error("Only less than 32 bit data can format to dec")
    @show_type=type

  toList: =>
    list=[]
    for i in _.range(@width)
      list.push(@bit(i))
    return list

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
    out=Vnumber.create(@bits[m..n].reverse().join(''),n-m)
    return packEl('num',out)

module.exports=Vnumber

