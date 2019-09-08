{ Port,input,output,channel,reg,wire,} = require 'chdl_base'
{toSignal} = require 'chdl_utils'
RecursiveIterator = require 'recursive-iterator'
ElementSets = require 'chdl_el_sets'
_ = require 'lodash'

module.exports={
  createSigArray: (type,number,width)->
    return (type() for i in [0...number])
  createChannelArray: (number)->
    return (channel() for i in [0...number])
  channelMux:(select,outChannel,inChannelList...)->
    for dst in outChannel.wireList()
      list=[]
      width=dst.net.getWidth()
      for src,index in inChannelList when dst.dir=='input'
        list.push("({#{width}{#{select.refName()}==#{index}}}&#{src.getWire(dst.path).refName()})")
        dst.net.pushDepNames(src.getWire(dst.path).refName())
      if dst.dir=='input'
        dst.net.assign(=> list.join("|\n\t"))
        dst.net.pushDepNames(select.refName())
      else if dst.dir=='output'
        for src,index in inChannelList
          src.getWire(dst.path).assign(=>dst.net.refName())
          src.getWire(dst.path).pushDepNames(dst.net.refName())

  mirrorPort:(i)->
    iterator=new RecursiveIterator(i)
    item=iterator.next()
    out={}
    while !item.done
      state = item.value
      if state.node.constructor.name=='Function' and state.node.__type=='port'
        width=state.node.getWidth()
        if state.node.getType()=='input'
          _.set(out,state.path,output(width))
        else if state.node.getType()=='output'
          _.set(out,state.path,input(width))
      item = iterator.next()
    return out

  bundleClone:(i)->
    iterator=new RecursiveIterator(i)
    item=iterator.next()
    out={}
    while !item.done
      state = item.value
      if state.node.constructor.name=='Function' and state.node.__type=='port'
        width=state.node.getWidth()
        if state.node.getType()=='input'
          _.set(out,state.path,input(width))
        else if state.node.getType()=='output'
          _.set(out,state.path,output(width))
      if state.node.constructor.name=='Function' and state.node.__type=='wire'
        width=state.node.getWidth()
        _.set(out,state.path,wire(width))
      if state.node.constructor.name=='Function' and state.node.__type=='reg'
        width=state.node.getWidth()
        _.set(out,state.path,reg(width))
      item = iterator.next()
    return out
    
  bundleUniOp:(op,o,i)->
    iterator=new RecursiveIterator(o)
    item=iterator.next()
    while !item.done
      state = item.value
      if state.node.constructor.name=='Function'
        if state.node.__type=='wire' or state.node.__type=='reg' or state.node.__type=='port'
          inWire=_.get(i,state.path)
          state.node.assign(=> "#{op}("+inWire.refName()+')')
      item = iterator.next()

  bundleReduceOp:(op,o,list)->
    iterator=new RecursiveIterator(o)
    item=iterator.next()
    while !item.done
      state = item.value
      if state.node.constructor.name=='Function'
        if state.node.__type=='wire' or state.node.__type=='reg' or state.node.__type=='port'
          sigList=[]
          for i in list
            sigList.push _.get(i,state.path).refName()
          state.node.assign(=> sigList.join("#{op}"))
      item = iterator.next()
}
