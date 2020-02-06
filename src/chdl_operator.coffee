_ =require 'lodash'
{getValue} = require('chdl_utils')

catItemValidate=(item)->
  if item.__type?
    if ['wire','reg','port'].includes(item.__type)
      return 1
    else
      return 0
  else if item.constructor?.name?
    if item.constructor.name == 'Vnumber'
      return 1
    else
      return 0
  else
    return 0

module.exports.cat= (args...)->
  list=[]
  if args.length==1 and _.isPlainObject(args[0])
    list=_.map(_.sortBy(_.entries(args[0]),(i)=>Number(i[0])),(i)=>i[1]).reverse()
  else if args.length==1 and _.isArray(args[0])
    list=args[0]
  else
    list=args
  for i,index in list
    if not catItemValidate(i)
      throw new Error("cat function item should be reg/wire/port or width number at position #{index}")
  return '{'+_.map(list,(i)=>getValue(i)).join(',')+'}'

module.exports.expand= (num,sig)->
  if not catItemValidate(sig)
    throw new Error("expand function item should be reg/wire/port or width number")
  return "{#{getValue(num)}{#{getValue(sig)}}}"

module.exports.all1     = (sig)-> return  "(&#{getValue(sig)})"
module.exports.all0     = (sig)-> return "!(|#{getValue(sig)})"
module.exports.has1     = (sig)-> return  "(|#{getValue(sig)})"
module.exports.has0     = (sig)-> return "!(&#{getValue(sig)})"
module.exports.hasOdd1  = (sig)-> return  "(^#{getValue(sig)})"
module.exports.hasEven1 = (sig)-> return "!(^#{getValue(sig)})"


