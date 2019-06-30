#{Channel}=require('./chdl_channel')
_ =require 'lodash'

toSignal= (i)->
  a=i.replace(/^\$\./,'')
  b=a.replace(/\./g,'__')
  return b

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
      "input "+toSignal(inst.elName)
    else
      "input ["+(inst.width-1)+":0] "+toSignal(inst.elName)
  else if type=='output'
    if inst.width==1
      "output "+inst.elName
    else
      "output ["+(inst.width-1)+":0] "+inst.elName

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
  for i in Object.keys(bin) when typeof bin[i] == 'function'
    ret[i]=bin[i]
  return ret
