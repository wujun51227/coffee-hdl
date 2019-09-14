#{Channel}=require('./chdl_channel')
_ =require 'lodash'

toSignal= (i)->
  a=i.replace(/^\$\./,'')
  b=a.replace(/\.$/,'')
  c=b.replace(/\./g,'__')
  return c

module.exports.toSignal=toSignal

toNumber=(s)->
  if isNaN(s)==false
    return Number(s)
  else if _.isString(s)
    if s.match(/^\d*'h/)
      toNumber(s.replace(/^\d*'h/,'0x'))
    else if s.match(/^\d*'o/)
      toNumber(s.replace(/^\d*'o/,'0o'))
    else if s.match(/^\d*'d/)
      toNumber(s.replace(/^\d*'d/,''))
    else if s.match(/^\d*'b/)
      toNumber(s.replace(/^\d*'d/,'0b'))
    else
      throw new Error(s+' is not a valid number format')
  else
    throw new Error(s+' is not a valid number format')


module.exports.toNumber=toNumber

toFlatten = (data,root='') ->
  result = []

  recurse = (cur, prop) ->
    if Object(cur) != cur
      result.push [prop, cur]
    else if cur.__type=='reg'
      result.push [prop, cur()]
      return
    else if cur.__type=='port'
      result.push [prop, cur()]
      return
    else if cur.__type=='wire'
      result.push [prop, cur()]
      return
    else if cur.constructor?.name=='Port'
      result.push [prop, cur]
      return
    else if cur.constructor?.name=='Channel'
      result.push [prop, cur]
      return
    else if cur.constructor?.name=='Wire'
      result.push [prop, cur]
      return
    else if cur.constructor?.name=='Reg'
      result.push [prop, cur]
      return
    else if cur.constructor?.name=='Vec'
      result.push [prop, cur]
      return
    else if _.isPlainObject(cur) and cur.leaf==true
      result.push [prop, cur]
      return
    else if Array.isArray(cur)
      i = 0
      l = cur.length
      while i < l
        recurse cur[i], if prop then prop + '.' + i else '' + i
        i++
    else if _.isFunction(cur)
      result.push [prop, cur]
      return
    else
      isEmpty = true
      for p of cur
        isEmpty = false
        recurse cur[p], if prop then prop + '.' + p else p
    return

  #if data instanceof CircuitEl
  #  if root==''
  #    root=data.refName()
  if Object.keys(data).length>0
    recurse data, root
  result

module.exports.toFlatten = toFlatten

#cloneIO= (io,out)->
#  if io.constructor?.name=='Port'
#    return Channel.create()
#  else if _.isPlainObject(io)
#    for k,v of io
#      if _.isPlainObject(v)
#        bin={}
#        out[k]=bin
#        cloneIO(v,bin)
#      else if _.isArray(v)
#        bin=[]
#        out[k]=bin
#        cloneIO(v,bin)
#      else
#        out[k]=Channel.create()
#  else if _.isArray(io)
#    for v in io
#      if _.isPlainObject(v)
#        bin={}
#        out.push bin
#        cloneIO(v,bin)
#      else if _.isArray(v)
#        bin=[]
#        out.push bin
#        cloneIO(v,bin)
#      else
#        out.push Channel.create()
#  #console.log '>>>>>',out
#  return out

#exports.cloneIO=cloneIO

module.exports.portDeclare= (type,inst)->
  if type=='input'
    if inst.width==1
      "input "+toSignal(inst.getName())
    else
      "input ["+(inst.width-1)+":0] "+toSignal(inst.getName())
  else if type=='output'
    if inst.width==1
      "output "+inst.getName()
    else
      "output ["+(inst.width-1)+":0] "+inst.getName()

dumpInfo= (elList)->
  ret={}
  _.map(toFlatten(elList), (i)=>
    path = i[0]
    inst = i[1]
    if inst.type?
      _.set(ret,path,{
        width:inst.width
        type:inst.type
        leaf:true
      })
    else
      _.set(ret,path,{
        width:inst.width
        leaf:true
      })
  )
  return ret

printBuffer= do ->
  bin=[]
  list=[]
  name=''
  inst=null
  dump= -> {
    name: name
    list: list
    info:
      ports: dumpInfo(inst.__ports)
      regs: dumpInfo(inst.__regs)
      wires: dumpInfo(inst.__wires)
  }
  return {
    reset: -> list=[]
    clearBin: -> bin.length=0
    add: (s)-> list.push s
    get: -> list
    blank: (s='')-> list.push s
    setName: (s)->
      bin.push(dump()) if list.length>0
      name=s
      list=[]
      inst=null
    flush: -> bin.push(dump()) if list.length>0
    getBin: -> bin
    dump: dump
    dumpAll: ->
      allBin=(i for i in bin).reverse()
      outList=[]
      outList.push '//*******************************************'
      outList.push "// Generate from coffee-hdl"
      outList.push "// #{new Date()} "
      outList.push '//*******************************************'
      outList.push "\n"
      for item in allBin
        outList.push '//**************************'
        outList.push "// Module #{item.name} "
        outList.push '//**************************'
        for line in item.list
          outList.push line
      return {
        name: name
        list: outList
        info:
          ports: dumpInfo(inst.__ports)
          regs: dumpInfo(inst.__regs)
          wires: dumpInfo(inst.__wires)
      }
    register:(i)->inst=i
    getInst: -> inst
  }

module.exports.printBuffer = printBuffer

module.exports.packEl = (type,bin)->
  ret = (msb=null,lsb=null)->
    if msb==null and lsb==null
      return bin
    else if lsb==null
      if _.isPlainObject(msb)
        pair=_.entries(msb)[0]
        return bin.slice(Number(pair[0]),Number(pair[1]))
      else
        return bin.bit(msb)
    else
      return bin.slice(msb+lsb-1,msb)
  ret.__type=type
  ret.getName= -> bin.getName()
  for i in Object.keys(bin) when typeof bin[i] == 'function'
    ret[i]=bin[i]
  return ret

__v=(width,number)->
  if width==null
    width=getWidth(number)
  if _.isString(number)
    if number.match(/^0x/)
      m=number.match(/^0x(.*)/)
      return "#{width}'h#{m[1]}"
    else if number.match(/^0o/)
      m=number.match(/^0o(.*)/)
      return "#{width}'o#{m[1]}"
    else if number.match(/^0b/)
      m=number.match(/^0b(.*)/)
      return "#{width}'b#{m[1]}"
    else
      if width=='1' or width==1
        return "1'b#{number}"
      else if width==''
        return "#{number}"
      else
        return "#{number}"
  else if _.isNumber(Number(number))
    if width==''
      return "#{number}"
    else if width=='1' or width==1
      return "1'b#{number}"
    else
      return "#{number}"
  else
    throw new Error("const value error")

module.exports.__v=__v

getWidth = (number)->
  if Number(number)==0
    return 1
  else
    Math.floor(Math.log2(Number(number))+1)

module.exports.hex = (n,m=null)->
  if m==null
    w=getWidth(n)
    __v(w,'0x'+(n>>>0).toString(16))
  else
    __v(n,'0x'+(m>>>0).toString(16))

module.exports.dec= (n,m=null)->
  if m==null
    w=getWidth(n)
    __v(w,n>>>0)
  else
    __v(n,m>>>0)

module.exports.oct= (n,m=null)->
  if m==null
    w=getWidth(n)
    __v(w,'0o'+(n>>>0).toString(8))
  else
    __v(n, '0o'+(m>>>0).toString(8))

module.exports.bin= (n,m=null)->
  if m==null
    w=getWidth(n)
    __v(w,'0b'+(n>>>0).toString(2))
  else
    __v(n, '0b'+(m>>>0).toString(2))

getValue=(i)=>
  if _.isString(i)
    return i
  if _.isNumber(i)
    return i
  if i.constructor?.name=='Expr'
    return i.str
  if i.constructor?.name=='Port'
    return i.refName()
  if i.constructor?.name=='Wire'
    return i.refName()
  if i.constructor?.name=='Reg'
    return i.refName()
  if i.constructor?.name=='BehaveReg'
    return i.refName()
  if _.isFunction(i)
    return i().refName()
  throw new Error('arg type error'+i)

module.exports.cat= (args...)->
  if args.length==1 and _.isPlainObject(args[0])
    list=_.map(_.sortBy(_.entries(args[0]),(i)=>Number(i[0])),(i)=>getValue(i[1])).reverse()
    return '{'+list.join(',')+'}'
  else if args.length==1 and _.isArray(args[0])
    list=_.map(args[0],(i)=>getValue(i))
    return '{'+list.join(',')+'}'
  else
    list=_.map(args,(i)=>getValue(i))
    return '{'+list.join(',')+'}'

module.exports.expand= (num,sig)->
  return "{#{getValue(num)}{#{getValue(sig)}}}"

module.exports._expr= (s) -> s.str
