{toSignal} = require('chdl_utils')
class CircuitEl

  constructor: ->
    @cell=null
    @elName=''
    @hier=''

  link: (cell,name)->
    @cell=cell
    @elName=toSignal(name)  # this name is flatten name
    @hier=name

  getName: -> @elName

  getPath: ->
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

module.exports=CircuitEl
