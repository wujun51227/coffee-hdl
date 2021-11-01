prefix = ''

indexTable={}

simMode=false

force=false

info=false

noLineno=false

waveFormat='vcd'

obfuscate=false

release=false

untouch_modules=[]

topName = null

idCnt=0

ifdefProtect=false

cdcCheck=false
cdcReportFile=null

outDir='./'

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

module.exports.isRelease= -> release

module.exports.setTopName = (n)-> topName=n

module.exports.getTopName = -> topName

module.exports.incrIdCnt= ->
  idCnt+=1
  return idCnt

module.exports.setIdCnt= (v)-> idCnt=v

module.exports.getIdCnt= -> idCnt

module.exports.setIfdefProtect= -> ifdefProtect=true

module.exports.getIfdefProtect= -> ifdefProtect

module.exports.setId = (id,inst)->
  indexTable[id]=inst

module.exports.queryId = (id)->
  return indexTable[id]

module.exports.dumpId= ->
  for k,v of indexTable
    console.log k,v.getPath()

module.exports.setCdcCheck = (file)->
  cdcCheck=true
  cdcReportFile = file ? null

module.exports.isCdcCheck = -> cdcCheck

module.exports.getCdcReportFile = -> cdcReportFile

module.exports.setOutDir=(v)->outDir=v
module.exports.getOutDir=->outDir
