Reg  = require 'chdl_reg'
Wire = require 'chdl_wire'
Port = require 'chdl_port'
_    = require 'lodash'

class Expr
  str: ''

  module: null

  @start: (module)-> new Expr(module)

  constructor: (@module)->

  next: (s=null)->
    if typeof(s)=='string'
      @str+=s
    else if typeof(s)=='number'
      @str+=s
    else if s==null
      @str+=''
    else if s.__type? and s.__type=='reg'
      @str+= s().refName()
    else if s.__type? and s.__type=='wire'
      @str+= s().refName()
    else if s.__type? and s.__type=='port'
      @str+= s().refName()
    else if s instanceof Reg
      @str+= s.refName()
    else if s instanceof Wire
      @str+= s.refName()
    else if s.constructor?.name=='Channel'
      @str+= s.elName
    else if s instanceof Expr
      @str+=s.str
    else if _.isPlainObject(s)
      return s
    else if _.isArray(s)
      return s
    else
      console.log s
      throw new Error("unkown next "+Object.keys(s))
    if s=='begin' || s=='end'
      @str+="\n"
    return this

module.exports=Expr
