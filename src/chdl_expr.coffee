_    = require 'lodash'
{getValue} = require('chdl_utils')

sharpToDot = (s)->  s.replace(/#/g,'.')

class Expr
  str: ''

  wstr: ''

  @start: -> new Expr()

  constructor: ()->

  next: (s=null)->
    if typeof(s)=='string'
      @str+=s
      @wstr+=s
    else if typeof(s)=='number'
      @str+=s
      @wstr+='w'+s.toString(2).length
    else if s==null
      @str+=''
      @wstr+=''
    else if s.__type? and s.__type=='expr'
      @str+='('+s.e.str+s.append+')'
      @wstr+='('+s.e.wstr+')'
    else if s.__type? and s.__type=='reg'
      n=s.refName()
      @str+= n
      @wstr+= 'w'+s.getWidth()
    else if s.__type? and s.__type=='wire'
      n=s.refName()
      @str+= n
      @wstr+= 'w'+s.getWidth()
    else if s.__type? and s.__type=='port'
      n=s.refName()
      @str+= n
      @wstr+= 'w'+s.getWidth()
    else if s.__type? and s.__type=='op_cat'
      @str+= '{ '+_.map(s.list,(i)=>getValue(i)).join(',')+' }'
      @wstr+= '( '+_.map(s.list,(i)=>'w'+i.getWidth()).join('*')+' )'
    else if s.__type? and s.__type=='op_expand'
      @str+= '{ '+getValue(s.num)+'{'+getValue(s.sig)+'}'+' }'
      @wstr+= '( '+getValue(s.num)+'**'+s.sig.getWidth()+' )'
    else if s.constructor?.name == 'Vnumber'
      n=s.refName()
      @str+= n
      @wstr+= 'w'+s.getWidth()
    else if s.constructor?.name == 'Vconst'
      n=s.refName()
      @str+= n
      @wstr+= 'w'+s.value.toString(2).length
    else if s instanceof Expr
      @str+=s.str
      @wstr+= s.wstr
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
