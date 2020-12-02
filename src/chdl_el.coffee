{toSignal} = require('chdl_utils')
global= require 'chdl_global'
class CircuitEl

  constructor: ->
    @cell=null
    @elName=''
    @hier=''

  link: (cell,name)->
    @cell=cell
    @elName=toSignal(name)  # this name is flatten name
    @hier=name

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

  getPathStr: =>
    return @getPath().join('.')

module.exports=CircuitEl
