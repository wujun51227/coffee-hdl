
class ElementSets

  @bin=[]

  constructor: ->

  @add: (name)-> @bin.push(name)

  @clear: -> @bin=[]

  @get: -> @bin

module.exports=ElementSets
