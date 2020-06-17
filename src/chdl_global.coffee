prefix = ''

simMode=false

force=false

info=false

noLineno=false

waveFormat='vcd'

obfuscate=false

module.exports.setPrefix = (s)-> prefix=s

module.exports.getPrefix = -> prefix

module.exports.setSim= -> simMode=true

module.exports.getSim= -> simMode

module.exports.setForce= -> force=true

module.exports.getForce= -> force

module.exports.setInfo= -> info=true

module.exports.getInfo= -> info

module.exports.setNoLineno= -> noLineno=true

module.exports.getNoLineno= -> noLineno

module.exports.setFsdbFormat = -> waveFormat='fsdb'

module.exports.getWaveFormat = -> waveFormat

module.exports.setNoWave= -> waveFormat=null

module.export.setObfuscate= -> obfuscate=true
module.export.getObfuscate= -> obfuscate
