_ =require 'lodash'
global= require 'chdl_global'


toSignal= (i)->
  a=i.replace(/^\$\./,'')
  b=a.replace(/\.$/,'')
  c=b.replace(/\./g,'__')
  d=c.replace(/#/g,'.')
  return d

module.exports.toSignal=toSignal

module.exports.toHier= (a,b)->
  if a? and b? and a.trim()!='' and b.trim()!=''
    return a+'.'+b
  if a? and a.trim()!=''
    return a
  if b? and b.trim()!=''
    return b
  return ''

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

toFlatten = (data,target=null,root='') ->
  result = []

  recurse = (cur, prop) ->
    checkTarget=->
      if target? and cur.__type? and cur.__type!=target
        throw new Error("Flatten target is #{target} but find type #{cur.__type}")
    if Object(cur) != cur
      result.push [prop, cur]
    else if cur.__type=='reg'
      checkTarget()
      result.push [prop, cur()]
      return
    else if cur.__type=='port'
      checkTarget()
      result.push [prop, cur()]
      return
    else if cur.__type=='wire'
      checkTarget()
      result.push [prop, cur()]
      return
    else if cur.__type=='expr'
      checkTarget()
      result.push [prop, cur]
      return
    else if cur.constructor?.name=='Port'
      checkTarget()
      result.push [prop, cur]
      return
    else if cur.constructor?.name=='Channel'
      checkTarget()
      result.push [prop, cur]
      return
    else if cur.constructor?.name=='Wire'
      checkTarget()
      result.push [prop, cur]
      return
    else if cur.constructor?.name=='Reg'
      checkTarget()
      result.push [prop, cur]
      return
    else if cur.constructor?.name=='Vec'
      checkTarget()
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

outBufferGen= ->
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
    clearBin: ->
      bin.length=0
      list=[]
      name=''
      inst=null
    add: (s)-> list.push s if s?
    blank: (s='')-> list.push s
    setName: (s,cell)->
      name=s
      inst=cell
      list=[]
    flush: ->
      bin.push(dump()) if list.length>0
    getBin: -> bin
    dumpAll: ->
      allBin=(i for i in bin).reverse()
      modules=[]
      outList=[]
      outList.push '//*******************************************'
      outList.push "// Generate from coffee-hdl"
      outList.push "// #{new Date()} "
      outList.push '//*******************************************'
      outList.push "\n"
      infoTable={}
      for item in allBin
        outList.push '//**************************'
        outList.push "// Module #{item.name} "
        outList.push '//**************************'
        modules.push item.name
        infoTable[item.name]=item.info
        for line in item.list
          outList.push line
      return {
        name: name
        modules: modules
        list: outList
        info: infoTable
      }
  }

module.exports.printBuffer = outBufferGen()
module.exports.simBuffer = outBufferGen()

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
  ret.sign= -> bin.sign()
  for i in Object.keys(bin) when typeof bin[i] == 'function'
    ret[i]=bin[i]
  return ret

module.exports.getValue=(i)=>
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
  if i.constructor?.name=='Vnumber'
    return i.refName()
  if _.isFunction(i)
    return i().refName()
  throw new Error('arg type error'+i)

module.exports._expr= (s,lineno=null) ->
  append=''
  if lineno? and lineno>=0
    append=' /* '+lineno+' */ '
  if s.constructor?.name == 'Expr'            # return simple expression
    ret={
      __type : 'expr'
      e: s
      append: append
    }
    return ret
  else if _.isArray(s) # return condition array
    return s
  else if _.isPlainObject(s) # return signal packet
    return s

ifToCond=(block,index,bin) =>
  while index<block.length
    i=block[index]
    if i[0]=='if'
      nextBin=[]
      bin.push({type:'cond',e:i[1],action:nextBin})
      index=ifToCond(block,index+1,nextBin)
    else if i[0]=='elseif'
      nextBin=[]
      bin.push({type:'cond',e:i[1],action:nextBin})
      index=ifToCond(block,index+1,nextBin)
    else if i[0]=='else'
      nextBin=[]
      bin.push({type:'cond',e:null,action:nextBin})
      index=ifToCond(block,index+1,nextBin)
    else if i[0]=='end'
      break
    else if i[0]=='endif'
      bin.push({type:'condend'})
    index+=1
  return index

module.exports.toEventList=(initSegmentList,list=[])=>
  for initSegment in initSegmentList
    item = initSegment
    if item.type=='delay'
      block=[]
      ifToCond(item.list,0,block)
      list.push {type:'delay',e:item.delay,block:block}
    else if item.type=='posedge'
      block=[]
      ifToCond(item.list,0,block)
      list.push {type:'posedge',e:item.signal,block:block}
    else if item.type=='negedge'
      block=[]
      ifToCond(item.list,0,block)
      list.push {type:'negedge',e:item.signal,block:block}
    else if item.type=='wait'
      block=[]
      ifToCond(item.list,0,block)
      list.push {type:'wait',e:item.expr,block:block}
    else if item.type=='event'
      block=[]
      ifToCond(item.list,0,block)
      list.push {type:'event',e:item.event,block:block}
    else if item.type=='trigger'
      block=[]
      ifToCond(item.list,0,block)
      list.push {type:'trigger',e:item.signal,block:block}
    else if item.type=='idle'
      block=[]
      ifToCond(item.list,0,block)
      list.push {type:'init',e:item.signal,block:block}

