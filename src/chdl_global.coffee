prefix = ''

simMode=false

force=false

info=false

noLineno=false

waveFormat='vcd'

obfuscate=false

release=false

untouch_modules=[]

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

module.exports.setObfuscate= -> obfuscate=true

module.exports.getObfuscate= -> obfuscate

module.exports.setUntouchModules=(list) ->
  untouch_modules=list

module.exports.getUntouchModules=(list) -> untouch_modules

module.exports.setRelease= -> release=true

module.exports.getRelease= -> release

