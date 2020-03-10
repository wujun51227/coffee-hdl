CircuitEl = require 'chdl_el'

class VecMember extends CircuitEl

  constructor: (vec,index,width)->
    super()
    @width=width
    @index=index
    @vec=vec
    @__type='vec_member'

  @create: (vec,index)-> new VecMember(vec,index,vec.getWidth())

  getWidth: -> @width

  refName: -> @vec.getName()+'['+@index+']'

module.exports=VecMember
