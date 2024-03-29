coffee = require 'coffeescript'
_ = require 'lodash'
fs = require 'fs'
log = require 'fancy-log'
{printBuffer,cat,hex,dec,oct,bin,__v,expand}=require 'chdl_utils'
chdl_base = require 'chdl_base'

reloadList=[]

debugExpr=''

printTokens=(tokens)->
  printOut=''
  for token in tokens
    if token[0]=='TERMINATOR'
      console.log printOut
      printOut=''
    else if token[0]=='INDENT'
      printOut+="<<INDENT>>"
    else if token[0]=='OUTDENT'
      printOut+="<<OUTDENT>>"
    else
      printOut+=token[1]+' '
  console.log printOut

getArgs= (tokens)->
  cnt=0
  ret=[]
  bin=[]
  for token in tokens
    if cnt==0 and token[0]==','
      ret.push bin
      bin=[]
    else if token[0]=='CALL_START'
      bin.push token
      cnt++
    else if token[0]=='CALL_END'
      bin.push token
      cnt--
    else
      bin.push token
  if bin.length>0
    ret.push bin
  #console.log '>>get args',ret
  return ret

findCallSlice=(tokens,index)->
  i=index
  cnt=0
  start=-1
  while token = tokens[i]
    if token[0]=='CALL_START'
      if start==-1
        start=i
      cnt++
    else if token[0]=='CALL_END'
      cnt--
      if cnt==0
        return [start,i]
    i++
  return [start,-1]

findBreak=(tokens,index)->
  i=index
  cnt=0
  while token = tokens[i]
    if token[0]=='TERMINATOR'
      return i
    else if token[0]=='INDENT'
      cnt+=1
    else if token[0]=='OUTDENT'
      cnt-=1
      if cnt==-1
        return i
    i+=1
  return -1

findCallBound=(tokens,index)->
  i=index
  cnt=0
  start=-1
  while token = tokens[i]
    if token[0]=='CALL_START'
      if start==-1
        start=i
      cnt++
    else if token[0]=='CALL_END'
      cnt--
      if cnt==0
        unless (tokens[i+1]? and tokens[i+1][0]=='CALL_START')
          return [start,i]
    i++
  return [start,-1]

findIndexBound=(tokens,index)->
  i=index
  cnt=0
  start=-1
  while token = tokens[i]
    if token[0]=='INDEX_START'
      if start==-1
        start=i
      cnt++
    else if token[0]=='INDEX_END'
      cnt--
      if cnt==0
        unless (tokens[i+1]? and tokens[i+1][0]=='INDEX_START')
          return [start,i]
    i++
  return [start,-1]

findPropertyBound=(tokens,index)->
  i=index
  start=index
  while token = tokens[i]
    if token[0]=='.' and tokens[i+1][0]=='PROPERTY'
      i+=2
      continue
    else if token[0]=='CALL_START'
      [dummy,stop_index]=findCallBound(tokens,i)
      i=stop_index+1
    else if token[0]=='INDEX_START'
      [dummy,stop_index]=findIndexBound(tokens,i)
      i=stop_index+1
    else
      break
  if i==start
    return [start,-1]
  else
    return [start,i-1]

findAssignBound=(tokens,index)->
  i=index
  start=index
  first=true
  while token = tokens[i]
    if first and token[0]=='IDENTIFIER'
      i+=1
      first=false
      continue
    if first and token[0]=='@'
      i+=2
      first=false
      continue
    if token[0]=='.' and tokens[i+1][0]=='PROPERTY'
      i+=2
      continue
    else if token[0]=='CALL_START'
      [dummy,stop_index]=findCallBound(tokens,i)
      i=stop_index+1
    else if token[0]=='INDEX_START'
      [dummy,stop_index]=findIndexBound(tokens,i)
      i=stop_index+1
    else
      break
  if i==start
    return [start,-1]
  else
    return [start,i-1]

findIndentSlice=(tokens,index)->
  i=index
  cnt=0
  start=-1
  while token = tokens[i]
    if token[0]=='INDENT'
      if start==-1
        start=i
      cnt++
    else if token[0]=='OUTDENT'
      cnt--
      if cnt==0
        return [start,i]
    i++
  return [start,-1]

findAssignBlock= (tokens,callEnd)->
  if tokens[callEnd+1][0] is '='
    if tokens[callEnd+2][0] is 'IDENTIFIER' and tokens[callEnd+2][1] is '$'
      [dummy,exprCallEnd]=findCallSlice(tokens,callEnd+2)
      tokens.splice(exprCallEnd,0,
        ['CALL_END',')',{}]
      )
      tokens.splice(callEnd+1,1,
        ['CALL_START','(',{}]
        ['=>','=>',{}]
      )
      return 2
    else if tokens[callEnd+2][0] is 'IDENTIFIER' and tokens[callEnd+2][1].match(/^\$/)
      [dummy,exprCallEnd]=findCallSlice(tokens,callEnd+2)
      tokens.splice(exprCallEnd,0,
        ['CALL_END',')',{}]
      )
      tokens.splice(callEnd+1,1,
        ['CALL_START','(',{}]
        ['=>','=>',{}]
      )
      return 2
    else
      termEnd=findBreak(tokens,callEnd)
      tokens.splice(termEnd,0,
        ['CALL_END',')',{}]
        ['CALL_END',')',{}]
      )
      tokens.splice(callEnd+1,1,
        ['CALL_START','(',{}]
        ['=>','=>',{}]
        ['IDENTIFIER','$',{}]
        ['CALL_START','(',{}]
      )
      return 5
  else if tokens[callEnd+1][0] is 'INDENT'
    [dummy,indentout]=findIndentSlice(tokens,callEnd+1)
    tokens.splice(indentout+1,0,
      ['CALL_END',')',{}]
    )
    tokens.splice(callEnd+1,0,
      ['CALL_START','(',{}]
      ['=>','=>',{}]
    )
    return 3
  else
    return 0

findAlwaysBlock= (tokens,callEnd,lineno=-1)->
  if tokens[callEnd+1][0] is 'INDENT'
    [dummy,indentout]=findIndentSlice(tokens,callEnd+1)
    tokens.splice(indentout+1,0,
      ['CALL_END',')',{}]
    )
    tokens.splice(callEnd+1,0,
      ['CALL_START','(',{}]
      ['NUMBER',"'"+String(lineno)+"'",{}]
      [',',',',{}]
      ['=>','=>',{}]
    )
    return 5
  else
    tokens.splice(callEnd+2,0,
      ['NUMBER',"'"+String(lineno)+"'",{}]
      [',',',',{}]
    )
    return 2

findCondBlock= (tokens,callEnd)->
  if tokens[callEnd+1][0] is 'CALL_START' and tokens[callEnd+2][0] isnt '=>'
    [dummy,nextCallEnd]=findCallSlice(tokens,callEnd+1)
    tokens.splice(nextCallEnd,0,
      ['OUTDENT','2',{}]
    )
    tokens.splice(callEnd+2,0,
      ['=>','=>',{}]
      ['INDENT','2',{}]
    )
    return 3
  else if tokens[callEnd+1][0] is 'INDENT'
    [dummy,indentout]=findIndentSlice(tokens,callEnd+1)
    tokens.splice(indentout+1,0,
      ['CALL_END',')',{}]
    )
    tokens.splice(callEnd+1,0,
      ['CALL_START','(',{}]
      ['=>','=>',{}]
    )
    return 3
  else
    return 0



scanToken= (tokens,index)->
  ret=[]
  #console.log '>>>>>>tokens',index,tokens[index...]
  nativeItem = tokens[index][0]=='@' and tokens[index+1]?[0]=='PROPERTY'
  #constValue= tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='__v' and tokens[index+1]?[0]=='CALL_START'
  #constValue= tokens[index][0]=='@' and tokens[index+1]?[0]=='CALL_START'
  isHex = tokens[index][0]=='NUMBER' and tokens[index][1].match(/^0x/)
  isOct= tokens[index][0]=='NUMBER' and tokens[index][1].match(/^0o/)
  isBin= tokens[index][0]=='NUMBER' and tokens[index][1].match(/^0b/)
  isDec= tokens[index][0]=='NUMBER' and tokens[index][1].match(/^[0-9]/) and tokens[index+1]?[0]!='\\'
  getIndex=false
  if tokens[index][0]=='{'
    i=index
    cnt=0
    list=[]
    removeCnt=0
    while token = tokens[i]
      removeCnt+=1
      list.push token
      if token[0]=='{'
        cnt++
      else if token[0]=='}'
        cnt--
        if cnt==0
          return [removeCnt,list.slice(1,list.length-1)]
      i++
  else if isHex or isOct or isBin or isDec
    token=tokens[index]
    ret.push ['IDENTIFIER','__v',{}]
    ret.push ['CALL_START','(',{}]
    ret.push ['NULL','null',{}]
    ret.push [',',',',{}]
    ret.push ['STRING',"'"+String(token[1])+"'",{}]
    ret.push ['CALL_END',')',{}]
    return [1,ret]
  else if nativeItem
    start_index=index
    [dummy,stop_index]=findPropertyBound(tokens,index+2)
    if stop_index==-1
      list=tokens.slice(start_index,start_index+2)
      return [2,list]
    else
      list=tokens.slice(start_index,stop_index+1)
      return [
        list.length
        list
      ]
  else if tokens[index][0]=='NUMBER' and tokens[index+1][0]=='\\' and tokens[index+2]?[1].match(/^[hdob]/)
    token = ['STRING',"'"+tokens[index][1]+String("\\'"+tokens[index+2][1])+"'",{}]
    return [3,[token]]
  else if tokens[index][0]=='\\' and tokens[index+1]?[1].match(/^[hdob]/)
    token = ['STRING',"'"+String("\\'"+tokens[index+1][1])+"'",{}]
    return [2,[token]]
  else if tokens[index][0]=='STRING'
    token = ['STRING',String(tokens[index][1]),{}]
    return [1,[token]]
  else if tokens[index][0]=='IDENTIFIER' and tokens[index][1].match(/^[_a-zA-Z]/)
    start_index=index
    [dummy,stop_index]=findPropertyBound(tokens,index+1)
    if stop_index==-1
      return [1,[tokens[index]]]
    else
      list=tokens.slice(start_index,stop_index+1)
      return [
        list.length
        list
      ]
  else
    token = ['STRING',"'"+String(tokens[index][1])+"'",{}]
    return [1,[token]]

exprStart= () ->
  tokens=coffee.tokens 'chdl_base.Expr.start(this)'
  tokens.pop()
  debugExpr+='\nchdl_base.Expr.start(this)'
  return tokens

exprNext= (n...) ->
  dot       = [ '.',     '.',  { } ]
  method    = [ 'PROPERTY',    'next',  { } ]
  callStart = [ 'CALL_START',  '(',     { } ]
  callEnd   = [ 'CALL_END',     ')',    { } ]
  filter = _.filter(n,(i)=>i!=null and i[1]!="'"+"\n"+"'")
  str=''
  for i in filter
    str+=i[1]
  debugExpr+='.next('+str+')'
  return [dot,method,callStart,filter...,callEnd]

tokenIsElseIf=(tokens,index)->
  return tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='$elseif'

tokenIsElse=(tokens,index)->
  return tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='$else'

tokenIsEndIf=(tokens,index)->
  return tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='$endif'

expandOp=(tokens)->
  out=[]
  for i,index in tokens
    if i[0]=='IDENTIFIER' and i[1].match(/^\$\w+/)
      m=i[1].match(/^\$(.*)/)
      out.push( ['@', '@', {}])
      out.push( ['PROPERTY', '_'+m[1], {}])
    else
      out.push(i)
  return out

extractLogic = (tokens)->
  i = 0
  logicCallPair=[]
  findStartPos=false
  startPos=-1
  endPos=-1
  while token = tokens[i]
    if chdl_base.getConfig('noLineno')
      lineno=-1
    else
      lineno=token[2].first_line-4
    #console.log '>>>>>',token[0],token[1]
    if token[0] is 'IDENTIFIER' and token[1]=='$'
      list =[['IDENTIFIER', '_expr', {}]]
      [callStart,callEnd]=findCallSlice(tokens,i)
      if callStart>0 and callEnd>0
        extractSlice=tokens.slice(callStart+1,callEnd)
        extractSlice=expandOp(extractSlice)
        exprExpand(extractSlice)
        list.push tokens[callStart]
        list.push extractSlice...
        list.push [',',',',{}]
        list.push ['NUMBER',"'"+String(lineno)+"'",{}]
        list.push tokens[callEnd]
        tokens.splice i, callEnd-i+1, list...
        i+=list.length
      else
        throw new Error("Syntax error at #{lineno}")
    else if token[0] is 'IDENTIFIER' and token[1]=='assign'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_assign', {}]
      ]
      if tokens[i+1][0]=='CALL_START' and tokens[i+1].generated # no () to assign signal
        [dummy,callEnd]=findCallSlice(tokens,i)
        [dummy,stopIndex]=findAssignBound(tokens,i+2)
        tokens.splice callEnd, 1
        tokens.splice stopIndex+1, 0, ['CALL_END',')',{}]

      [callStart,callEnd]=findCallSlice(tokens,i)
      tokens.splice(callEnd,0,
        [',',',',{}],
        ['NUMBER',"'"+String(lineno)+"'",{}]
      )
      patchLength=findAssignBlock(tokens,callEnd+2)
      tokens.splice i, 1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='input'
      list =[
        ['IDENTIFIER', 'chdl_base', {}]
        [ '.',     '.',  { } ]
        ['PROPERTY', 'input', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Module'
      list =[
        ['IDENTIFIER', 'chdl_base', {}]
        [ '.',     '.',  { } ]
        ['PROPERTY', 'Module', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Port'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_port', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Channel'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_channel', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Probe'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_probe', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Wire'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_wire', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='local_wire'
      throw new Error('local_wire is deprecated,use wire')
    #  list =[
    #    ['@', '@', {}]
    #    ['PROPERTY', '_localWire', {}]
    #  ]
    #  tokens.splice i, 1, list...
    #  i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Net'
      netName = tokens[i+2][1]
      if tokens[i+3][0]==','
        width= tokens[i+4][1]
        list =[
          ['IDENTIFIER',netName,{}]
          ['=','=',{}]
          ['@', '@', {}]
          ['PROPERTY', '_localWire', {}]
          [ 'CALL_START',  '(',     { } ]
          [ 'NUMBER',  width,     { } ]
          [',',',',{}]
          ['STRING',"'"+netName+"'",{}]
          [ 'CALL_END',     ')',    { } ]
          [ 'TERMINATOR',   '\n',    { } ]
          ['@', '@', {}]
          ['PROPERTY', '_assign', {}]
        ]
      else
        list =[
          ['IDENTIFIER',netName,{}]
          ['=','=',{}]
          ['@', '@', {}]
          ['PROPERTY', '_localWire', {}]
          [ 'CALL_START',  '(',     { } ]
          [ 'NUMBER',  '1',     { } ]
          [',',',',{}]
          ['STRING',"'"+netName+"'",{}]
          [ 'CALL_END',     ')',    { } ]
          [ 'TERMINATOR',   '\n',    { } ]
          ['@', '@', {}]
          ['PROPERTY', '_assign', {}]
        ]
      if tokens[i+1][0]=='CALL_START' and tokens[i+1].generated # no () to assign signal
        [dummy,callEnd]=findCallSlice(tokens,i)
        [dummy,stopIndex]=findAssignBound(tokens,i+2)
        tokens.splice callEnd, 1
        tokens.splice stopIndex+1, 0, ['CALL_END',')',{}]

      [callStart,callEnd]=findCallSlice(tokens,i)
      tokens.splice(callEnd,0,
        [',',',',{}],
        ['NUMBER',"'"+String(lineno)+"'",{}]
      )
      patchLength=findAssignBlock(tokens,callEnd+2)
      tokens.splice i, 1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='local_reg'
      throw new Error('local_reg is deprecated,use reg')
    #  list =[
    #    ['@', '@', {}]
    #    ['PROPERTY', '_localReg', {}]
    #  ]
    #  tokens.splice i, 1, list...
    #  i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Reg'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_reg', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Mem'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_mem', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='CellMap'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_cellmap', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    #else if token[0] is 'IDENTIFIER' and token[1]=='Hub'
    #  list =[
    #    ['@', '@', {}]
    #    ['PROPERTY', '_hub', {}]
    #  ]
    #  tokens.splice i, 1, list...
    #  i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='output'
      list =[
        ['IDENTIFIER', 'chdl_base', {}]
        [ '.',     '.',  { } ]
        ['PROPERTY', 'output', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='vec'
      list =[
        ['IDENTIFIER', 'chdl_base', {}]
        [ '.',     '.',  { } ]
        ['PROPERTY', 'vec', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='bind'
      list =[
        ['IDENTIFIER', 'chdl_base', {}]
        [ '.',     '.',  { } ]
        ['PROPERTY', 'bind', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='reg'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_localReg', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='vreg'
      list =[
        ['IDENTIFIER', 'chdl_base', {}]
        [ '.',     '.',  { } ]
        ['PROPERTY', 'vreg', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='channel'
      list =[
        ['IDENTIFIER', 'chdl_base', {}]
        [ '.',     '.',  { } ]
        ['PROPERTY', 'channel', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='wire'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_localWire', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='importDesign'
      list =[
        ['IDENTIFIER', 'importLib', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='always'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_always', {}]
      ]
      patchLength=findAlwaysBlock(tokens,i,lineno)
      tokens.splice i, 1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='always_if'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_always_if', {}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push [',',',',{}]
      list.push ['NUMBER',"'"+String(lineno)+"'",{}]
      list.push tokens[callEnd]
      patchLength=findCondBlock(tokens,callEnd)
      tokens.splice i, callEnd-i+1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='forever'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_forever', {}]
      ]
      patchLength=findAlwaysBlock(tokens,i,lineno)
      tokens.splice i, 1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='initial'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_initial', {}]
      ]
      patchLength=findAlwaysBlock(tokens,i)
      tokens.splice i, 1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='Mixin'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_mixin', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    #else if token[0] is 'IDENTIFIER' and token[1]=='MixinAs'
    #  list =[
    #    ['@', '@', {}]
    #    ['PROPERTY', '_mixinas', {}]
    #  ]
    #  tokens.splice i, 1, list...
    #  i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$sequence'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_sequenceDef', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$if_blocks'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_if_blocks', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$if'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_if', {}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      if tokens[callEnd+1][0]=='CALL_START'
        [dummy,outdentIndex]=findCallSlice(tokens,callEnd+1)
      else
        [dummy,outdentIndex]=findIndentSlice(tokens,callEnd+1)
      find=false
      if tokens[outdentIndex+1][0]=='TERMINATOR'
        if tokenIsElseIf(tokens,outdentIndex+2) or tokenIsElse(tokens,outdentIndex+2) or tokenIsEndIf(tokens,outdentIndex+2)
          find=true
      if not find
        append_list=[
          ['.', '.', {}]
          ['PROPERTY', '_endif', {}]
          [ 'CALL_START',  '(',     { } ]
          [ 'CALL_END',     ')',    { } ]
        ]
        tokens.splice outdentIndex+1, 0, append_list...
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push [',',',',{}]
      list.push ['NUMBER',"'"+String(lineno)+"'",{}]
      list.push tokens[callEnd]
      patchLength=findCondBlock(tokens,callEnd)
      tokens.splice i, callEnd-i+1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='$elseif'
      list =[
        ['.', '.', {}] ,
        ['PROPERTY', '_elseif', {}]
      ]
      if tokens[i-1][0]=='TERMINATOR'
        tokens.splice i-1, 1
        i--
      [callStart,callEnd]=findCallSlice(tokens,i)
      if tokens[callEnd+1][0]=='CALL_START'
        [dummy,outdentIndex]=findCallSlice(tokens,callEnd+1)
      else
        [dummy,outdentIndex]=findIndentSlice(tokens,callEnd+1)
      find=false
      if tokens[outdentIndex+1][0]=='TERMINATOR'
        if tokenIsElseIf(tokens,outdentIndex+2) or tokenIsElse(tokens,outdentIndex+2) or tokenIsEndIf(tokens,outdentIndex+2)
          find=true
      if not find
        append_list=[
          ['.', '.', {}]
          ['PROPERTY', '_endif', {}]
          [ 'CALL_START',  '(',     { } ]
          [ 'CALL_END',     ')',    { } ]
        ]
        tokens.splice outdentIndex+1, 0, append_list...
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push [',',',',{}]
      list.push ['NUMBER',"'"+String(lineno)+"'",{}]
      list.push tokens[callEnd]
      patchLength=findCondBlock(tokens,callEnd)
      tokens.splice i, callEnd-i+1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='$else'
      list =[
        ['.', '.', {}]
        ['PROPERTY', '_else', {}]
        ['CALL_START', '(', {}]
        ['NUMBER',"'"+String(lineno)+"'",{}]
        ['CALL_END',  ')', {} ]
      ]
      if tokens[i+1][0]=='CALL_START'
        [dummy,outdentIndex]=findCallSlice(tokens,i+1)
      else
        [dummy,outdentIndex]=findIndentSlice(tokens,i+1)
      unless tokens[outdentIndex+1][0]=='TERMINATOR' and  tokenIsEndIf(tokens,outdentIndex+2)
        append_list=[
          ['.', '.', {}]
          ['PROPERTY', '_endif', {}]
          [ 'CALL_START',  '(',     { } ]
          [ 'CALL_END',     ')',    { } ]
        ]
        tokens.splice outdentIndex+1, 0, append_list...
      if tokens[i-1][0]=='TERMINATOR'
        tokens.splice i-1, 1
        i--
      patchLength=findCondBlock(tokens,i)
      tokens.splice i, 1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='$endif'
      list =[
        ['.', '.', {}]
        ['PROPERTY', '_endif', {}]
        [ 'CALL_START',  '(',     { } ]
        [ 'CALL_END',     ')',    { } ]
      ]
      if tokens[i-1][0]=='TERMINATOR'
        tokens.splice i-1, 1
        i--
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$cond'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_cond', {}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      if tokens[callEnd+1][0]!='CALL_START'
        append_list=[
          ['CALL_START',"(",{}]
          ['NULL',"null",{}]
          ['CALL_END',")",{}]
        ]
        tokens.splice callEnd+1, 0, append_list...
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      if extractSlice.length==0
        list.push ['NULL',"null",{}]
      else
        list.push extractSlice...
      list.push [',',',',{}]
      list.push ['NUMBER',"'"+String(lineno)+"'",{}]
      list.push tokens[callEnd]
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$lazy_cond'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_lazy_cond', {}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      if tokens[callEnd+1][0]!='CALL_START'
        append_list=[
          ['CALL_START',"(",{}]
          ['NULL',"null",{}]
          ['CALL_END',")",{}]
        ]
        tokens.splice callEnd+1, 0, append_list...
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      if extractSlice.length==0
        list.push ['NULL',"null",{}]
      else
        list.push extractSlice...
      list.push [',',',',{}]
      list.push ['NUMBER',"'"+String(lineno)+"'",{}]
      list.push tokens[callEnd]
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1].match(/^\$/)
      m=token[1].match(/^\$(.*)/)
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_'+m[1], {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if findstartPos and token[0] is 'CALL_START'
      findstartPos=false
      logicCallPair.push(true)
      i++
      startPos=i
    else if startPos>=0 and token[0] is 'CALL_START'
      logicCallPair.push(true)
      i++
    else if token[0] is 'CALL_END' and startPos>=0
      logicCallPair.pop()
      if logicCallPair.length==0
        endPos=i
        outdent=tokens[i-1]
        extractSlice=tokens.slice(startPos,endPos-1)
        #console.log ">>>>>>>>>logic slice",extractSlice,'>>',tokens[i]
        tokenExpand(extractSlice)
        tokens.splice startPos, endPos-startPos, extractSlice...,outdent
        i=startPos+extractSlice.length
        startPos=-1
        # console.log '>>>extract slice',extractSlice
      else
        i++
    else
      i++

exprExpand = (tokens)->
  i = 0
  state='logicStart'
  while token = tokens[i]
    if state=='logicStart'
      [n,replaceTokens]=scanToken(tokens,i)
      list=[exprStart()...,exprNext(replaceTokens...)...]
      tokens.splice i, n, list...
      state='logicNext'
      i+=list.length
    else if state=='logicNext'
      if token[0] is 'INDENT'
        list=exprNext(['STRING',"'begin'",{}])
        tokens.splice i, 1, list...
        i+=list.length
      else if token[0] is 'OUTDENT'
        list=exprNext(['STRING',"'end'",{}])
        tokens.splice i, 1, list...
        i+=list.length
      else if token[0] is 'TERMINATOR'
        state='logicStart'
        i++
      else
        [n,replaceTokens]=scanToken(tokens,i)
        list=exprNext(replaceTokens...)
        tokens.splice i, n, list...
        i+=list.length
    else
      i++

tokenExpand = (tokens,skip_indent=false)->
  i = 0
  state='idle'
  if skip_indent
    state='logicStart'
  while token = tokens[i]
    # console.log ">>>>>>logic block token",token[0],token[1]
    if state=='idle'
      if token[0] is 'INDENT'
        state='logicStart'
      i++
    else if state=='logicStart'
      [n,replaceTokens]=scanToken(tokens,i)
      list=[exprStart()...,exprNext(replaceTokens...)...]
      tokens.splice i, n, list...
      state='logicNext'
      i+=list.length
    else if state=='logicNext'
      if token[0] is 'INDENT'
        list=exprNext(['STRING',"'begin'",{}])
        tokens.splice i, 1, list...
        i+=list.length
      else if token[0] is 'OUTDENT'
        list=exprNext(['STRING',"'end'",{}])
        tokens.splice i, 1, list...
        i+=list.length
      else if token[0] is 'TERMINATOR'
        state='logicStart'
        i++
      else
        [n,replaceTokens]=scanToken(tokens,i)
        list=exprNext(replaceTokens...)
        tokens.splice i, n, list...
        i+=list.length
    else
      i++

buildCode= (fullFileName,text,debug=false,param=null) ->
  for i in reloadList
    delete require.cache[i]
  printBuffer.reset()
  design=transToJs(fullFileName,text,debug)
  chdl_base.toVerilog(new design(param))

buildLib= (fullFileName,text,debug=false,param=null) ->
  chdl_base.configBase({noLineno:true})
  transToJs(fullFileName,text,debug)

transToJs= (fullFileName,text,debug=false) ->
  head = "chdl_base = require 'chdl_base'\n"
  head +="{_expr,printBuffer,cat,hex,dec,oct,bin,__v,expand,all1,all0,has0,has1,hasOdd1,hasEven1}=require 'chdl_utils'\n"
  head += "{infer,cell}= require 'chdl_base'\n"
  head += "{importLib}= require 'chdl_transpiler_engine'\n"
  head += "module.paths.push('#{process.cwd()}')\n"
  text = head + text
  text+="\nreturn module.exports"
  tokens = coffee.tokens text
  if debug
    log "========================="
    log "origin Tokens"
    log "========================="
    printTokens(tokens)
  tokens=expandNum(tokens)
  extractLogic(tokens)
  options={
    referencedVars : ( token[1] for token in tokens when token[0] is 'IDENTIFIER')
    bare:false
  }

  if debug
    log "========================="
    log "extract Tokens"
    log "========================="
    printTokens(tokens)
    log "========================="
    log 'expr'
    log "========================="
    log debugExpr
  nodes = coffee.nodes tokens
  fragments=nodes.compileToFragments options
  javaScript = ''
  for fragment in fragments
    javaScript += fragment.code
  fs.writeFileSync("#{fullFileName}.js", javaScript,'utf8')
  reloadList.push("#{fullFileName}.js")
  return require("#{fullFileName}.js")

importLib=(path)->
  if path.match(/^\./)
    for i in module.paths
      fullName = require('path').resolve(i+'/'+path.replace(/\.chdl$/,'')+'.chdl')
      if fs.existsSync(fullName)
        text=fs.readFileSync(fullName, 'utf-8')
        module.paths.push require('path').dirname(fullName)
        return transToJs(fullName,text,false)
    throw new Error("Cant find file "+fullName)
  else if path.match(/\//)
    fullName= require('path').resolve(path.replace(/\.chdl$/,'')+'.chdl')
    if fs.existsSync(fullName)
      text=fs.readFileSync(fullName, 'utf-8')
      return transToJs(fullName,text,false)
    throw new Error("Cant find file "+fullName)
  else
    list=[]
    list.push(process.cwd())
    list.push(module.paths...)
    if process.env.CHDL_LIB?
      list.push(process.env.CHDL_LIB.split(/:/)...)
    list.push(process.env.NODE_PATH.split(/:/)...)
    for i in list
      fullName= require('path').resolve(i+'/'+path.replace(/\.chdl$/,'')+'.chdl')
      if fs.existsSync(fullName)
        text=fs.readFileSync(fullName, 'utf-8')
        return transToJs(fullName,text,false)
    throw new Error("Cant find file "+path)

expandNum=(tokens)->
  out=[]
  skip=0
  for i,index in tokens
    if skip>0
      skip-=1
    else if i[0]=='NUMBER' and tokens[index+1]?[0]=='\\' and tokens[index+2]?[1].match(/^[hdob]/)
      out.push ['STRING',"'"+tokens[index][1]+String("\\'"+tokens[index+2][1])+"'",{}]
      skip=2
    else
      out.push(i)
  return out

module.exports.buildCode= buildCode
module.exports.buildLib= buildLib
module.exports.setPaths= (paths)=>
  module.paths=(i for i in paths)
module.exports.importLib= importLib


