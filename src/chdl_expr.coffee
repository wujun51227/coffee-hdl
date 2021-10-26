_    = require 'lodash'
{getValue} = require('chdl_utils')

class Expr
  @start: -> new Expr()

  constructor: ()->
    @str= ''
    @wstr= ''
    @driven=[]

  next: (s=null)->
    if typeof(s)=='string'
      @str+=s
      @wstr+=s
    else if typeof(s)=='number'
      @str+=s
      @wstr+=s.toString(10)
    else if s==null
      @str+=''
      @wstr+=''
    else if s.__type? and s.__type=='expr'
      @str+='('+s.e.str+s.append+')'
      @wstr+='('+s.e.wstr+')'
      @driven.push(s.e.driven...)
    else if s.__type? and s.__type=='reg'
      n=s.refName()
      @str+= n
      @wstr+= 'w'+s.getWidth()
      @driven.push(s.getId())
    else if s.__type? and s.__type=='wire'
      n=s.refName()
      @str+= n
      @wstr+= 'w'+s.getWidth()
      @driven.push(s.getId())
    else if s.__type? and s.__type=='port'
      n=s.refName()
      @str+= n
      @wstr+= 'w'+s.getWidth()
      @driven.push(s.getId())
    else if s.__type? and s.__type=='op_all1'
      if s.sig.__type? and ['reg','wire','port'].includes(s.sig.__type)
        @driven.push(s.sig.getId())
      @str+= '(&('+getValue(s.sig)+'))'
      @wstr+= '( w1 )'
    else if s.__type? and s.__type=='op_all0'
      if s.sig.__type? and ['reg','wire','port'].includes(s.sig.__type)
        @driven.push(s.sig.getId())
      @str+= '(!(|('+getValue(s.sig)+')))'
      @wstr+= '( w1 )'
    else if s.__type? and s.__type=='op_has1'
      if s.sig.__type? and ['reg','wire','port'].includes(s.sig.__type)
        @driven.push(s.sig.getId())
      @str+= '(|('+getValue(s.sig)+'))'
      @wstr+= '( w1 )'
    else if s.__type? and s.__type=='op_has0'
      if s.sig.__type? and ['reg','wire','port'].includes(s.sig.__type)
        @driven.push(s.sig.getId())
      @str+= '(!(&('+getValue(s.sig)+')))'
      @wstr+= '( w1 )'
    else if s.__type? and s.__type=='op_hasOdd1'
      if s.sig.__type? and ['reg','wire','port'].includes(s.sig.__type)
        @driven.push(s.sig.getId())
      @str+= '(^('+getValue(s.sig)+'))'
      @wstr+= '( w1 )'
    else if s.__type? and s.__type=='op_hasEven1'
      if s.sig.__type? and ['reg','wire','port'].includes(s.sig.__type)
        @driven.push(s.sig.getId())
      @str+= '(!(^('+getValue(s.sig)+')))'
      @wstr+= '( w1 )'
    else if s.__type? and s.__type=='op_cat'
      for i in s.list
        if i.__type? and ['reg','wire','port'].includes(i.__type)
          @driven.push(i.getId())
      @str+= '{ '+_.map(s.list,(i)=>getValue(i)).join(',')+' }'
      @wstr+= '( '+_.map(s.list,(i)=>'w'+i.getWidth()).join('*')+' )'
    else if s.__type? and s.__type=='op_expand'
      if s.sig.__type? and ['reg','wire','port'].includes(s.sig.__type)
        @driven.push(s.sig.getId())
      @str+= '{ '+getValue(s.num)+'{'+getValue(s.sig)+'}'+' }'
      @wstr+= '( '+getValue(s.num)+'**'+s.sig.getWidth()+' )'
    else if s.constructor?.name == 'Vnumber'
      n=s.refName()
      @str+= n
      if s.isAutoWidth()
        @wstr+= s.getNumber()
      else
        @wstr+= 'w'+s.getWidth()
    else if s.constructor?.name == 'Vconst'
      n=s.refName()
      @str+= n
      @wstr+= 'w'+s.value.toString(2).length
    else if s.constructor?.name == 'VecMember'
      n=s.refName()
      @str+= n
      @wstr+= 'w'+s.getWidth()
    else if s instanceof Expr
      @str+=s.str
      @wstr+= s.wstr
      @driven.push(s.driven...)
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
