Wire=require 'chdl_wire'

class Vconst extends Wire

  @create: (name,value)-> new Vconst(name,value)

  constructor: (name,value)->
    super(32)
    @value=value
    @label=name

  assign: ()=>
    throw new Error("const can not be assigned")

  verilogDeclare: ->
    "localparam "+@elName+"="+@value+";"

  verilogUpdate: -> null

module.exports=Vconst
