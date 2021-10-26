{toSignal} = require('chdl_utils')
uuid  = require 'uuid/v1'
class CircuitEl

  constructor: ->
    @cell=null
    @elName=''
    @hier=''
    @uuid=uuid()

  getId: => @uuid

  link: (cell,name)->
    @cell=cell
    @elName=toSignal(name)  # this name is flatten name
    @hier=name

  getCell:=> @cell

  toString: ->
    @hier+'(...)'

  getName: -> @elName

  sign: -> "$signed(#{toSignal(@hier)})"

  getPath: =>
    list=[@elName]
    cell=@cell
    while(1)
      if cell.__parentNode?
        list.push cell.__instName
        cell=cell.__parentNode
      else
        list.push cell.constructor.name
        break
    return list.reverse()

  oomrName: =>
    return @getPath().join('.')

module.exports=CircuitEl
