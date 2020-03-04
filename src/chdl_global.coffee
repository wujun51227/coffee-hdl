prefix = ''

simMode=false

force=false

module.exports.setPrefix = (s)-> prefix=s

module.exports.getPrefix = -> prefix

module.exports.setSim= -> simMode=true

module.exports.getSim= -> simMode

module.exports.setForce= -> force=true

module.exports.getForce= -> force

