prefix = ''

simMode=false

module.exports.setPrefix = (s)-> prefix=s

module.exports.getPrefix = -> prefix

module.exports.setSim= -> simMode=true

module.exports.getSim= -> simMode
