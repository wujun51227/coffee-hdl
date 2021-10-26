CircuitEl = require 'chdl_el'
VecMember = require 'chdl_vec_member'
{getValue} = require 'chdl_utils'
_ = require 'lodash'

class Vec extends CircuitEl

  constructor: (width,depth,annotate=null)->
    super()
    @width=width
    @depth=depth
    @__annotate=annotate

  set: (n,expr)=>
    addr=getValue(n)
    @cell.__regAssignList.push ["assign",VecMember.create(this,addr),expr,-1]

  get: (n)=>
    addr=getValue(n)
    return VecMember.create(this,addr)

  array_set: (n,cond,expr,clk=null)=>
    addr=getValue(n)
    if clk?
      @cell.__wireAssignList.push ["array_set",VecMember.create(this,addr),[cond,expr,clk.refName()],-1]
    else
      @cell.__wireAssignList.push ["array_set",VecMember.create(this,addr),[cond,expr,@cell._clock()],-1]

  array_get: (n,cond,target,clk=null)=>
    addr=getValue(n)
    if clk?
      @cell.__wireAssignList.push ["array_get",VecMember.create(this,addr),[cond,target,clk.refName()],-1]
    else
      @cell.__wireAssignList.push ["array_get",VecMember.create(this,addr),[cond,target,@cell._clock()],-1]
    
  @create: (width,depth,annotate=null)-> new Vec(width,depth,annotate)

  getWidth:()=> @width

  getDepth:()=> @depth

  readmemh: (self,path)=>
    oomr=true
    if @cell.getModuleName()==self.getModuleName()
      oomr=false
    if _.isString(path)
      self.__regAssignList.push ["array_init",this,['hex','"'+path+'"',oomr],-1]
    else if path.constructor?.name=='Vconst'
      self.__regAssignList.push ["array_init",this,['hex',path.label,oomr],-1]
    else
      self.__regAssignList.push ["array_init",this,['hex',path,oomr],-1]

  verilogDeclare: ()->
    if @__annotate?
      return "reg ["+(@width-1)+":0] "+@elName+"[0:"+(@depth-1)+"]; /* #{@__annotate} */"
    else
      return "reg ["+(@width-1)+":0] "+@elName+"[0:"+(@depth-1)+"];"

module.exports=Vec
