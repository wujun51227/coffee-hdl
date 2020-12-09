coffee = require 'coffeescript'
_ = require 'lodash'
fs = require 'fs'
md5 = require 'md5'
log = require 'fancy-log'
{printBuffer,cat,expand}=require 'chdl_utils'
chdl_base = require 'chdl_base'
global = require 'chdl_global'
Path = require 'path'

reloadList=[]

headOver=6

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
  if tokens[callEnd+1][0] is 'INDENT'
    [dummy,indentout]=findIndentSlice(tokens,callEnd+1)
    tokens.splice(indentout+1,0,
      ['CALL_END',')',{range:[]}]
    )
    tokens.splice(callEnd+1,0,
      ['CALL_START','(',{range:[]}]
      ['=>','=>',{range:[]}]
    )
    return 3
  else
    return 0

findAlwaysBlock= (tokens,callEnd,lineno=-1)->
  if tokens[callEnd+1][0] is 'INDENT'
    [dummy,indentout]=findIndentSlice(tokens,callEnd+1)
    tokens.splice(indentout+1,0,
      ['CALL_END',')',{range:[]}]
    )
    tokens.splice(callEnd+1,0,
      ['CALL_START','(',{range:[]}]
      ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
      [',',',',{range:[]}]
      ['=>','=>',{range:[]}]
    )
    return 5
  else
    tokens.splice(callEnd+2,0,
      ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
      [',',',',{range:[]}]
    )
    return 2

findCondBlock= (tokens,callEnd)->
  if tokens[callEnd+1][0] is 'CALL_START' and tokens[callEnd+2][0] isnt '=>'
    [dummy,nextCallEnd]=findCallSlice(tokens,callEnd+1)
    tokens.splice(nextCallEnd,0,
      ['OUTDENT','2',{range:[]}]
    )
    tokens.splice(callEnd+2,0,
      ['=>','=>',{range:[]}]
      ['INDENT','2',{range:[]}]
    )
    return 3
  else if tokens[callEnd+1][0] is 'INDENT'
    [dummy,indentout]=findIndentSlice(tokens,callEnd+1)
    tokens.splice(indentout+1,0,
      ['CALL_END',')',{range:[]}]
    )
    tokens.splice(callEnd+1,0,
      ['CALL_START','(',{range:[]}]
      ['=>','=>',{range:[]}]
    )
    return 3
  else
    return 0

scanToken= (tokens,index)->
  ret=[]
  nativeItem1 = tokens[index][0]=='@' and tokens[index+1]?[0]=='PROPERTY'
  nativeItem2 = tokens[index][0]=='THIS' and tokens[index+1]?[0]=='.' and tokens[index+2]?[0]=='PROPERTY'
  isHex = tokens[index][0]=='NUMBER' and tokens[index][1].match(/^0x/)
  isOct= tokens[index][0]=='NUMBER' and tokens[index][1].match(/^0o/)
  isBin= tokens[index][0]=='NUMBER' and tokens[index][1].match(/^0b/)
  isDec= tokens[index][0]=='NUMBER' and tokens[index][1].match(/^[0-9]/)
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
  else if isHex
    token=tokens[index]
    newTokens=[
      [
        "IDENTIFIER", "hex", {range:[]}
      ],
      [
        "CALL_START", "(", {range:[]}
      ],
      [
        "NUMBER", String(token[1]), {range:[]}
      ],
      [
        "CALL_END", ")", {range:[]}
      ]
    ]
    ret.push newTokens...
    return [1,ret]
  else if isOct
    token=tokens[index]
    newTokens=[
      [
        "IDENTIFIER", "oct", {range:[]}
      ],
      [
        "CALL_START", "(", {range:[]}
      ],
      [
        "NUMBER", String(token[1]), {range:[]}
      ],
      [
        "CALL_END", ")", {range:[]}
      ]
    ]
    ret.push newTokens...
    return [1,ret]
  else if isBin
    token=tokens[index]
    newTokens=[
      [
        "IDENTIFIER", "bin", {range:[]}
      ],
      [
        "CALL_START", "(", {range:[]}
      ],
      [
        "NUMBER", String(token[1]), {range:[]}
      ],
      [
        "CALL_END", ")", {range:[]}
      ]
    ]
    ret.push newTokens...
    return [1,ret]
  else if isDec
    token=tokens[index]
    newTokens=[
      [
        "IDENTIFIER", "dec", {range:[]}
      ],
      [
        "CALL_START", "(", {range:[]}
      ],
      [
        "NUMBER", String(token[1]), {range:[]}
      ],
      [
        "CALL_END", ")", {range:[]}
      ]
    ]
    ret.push newTokens...
    return [1,ret]
  else if nativeItem1
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
  else if nativeItem2
    start_index=index
    [dummy,stop_index]=findPropertyBound(tokens,index+3)
    if stop_index==-1
      list=tokens.slice(start_index,start_index+3)
      return [3,list]
    else
      list=tokens.slice(start_index,stop_index+1)
      return [
        list.length
        list
      ]
  else if tokens[index][0]=='STRING'
    token = ['STRING',String(tokens[index][1]),{range:[]}]
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
    if tokens[index][1].match(/^\$/)
      token1 = ['@','@',{range:[]}]
      token2 = ['PROPERTY',tokens[index][1].replace(/^\$/,'_'),{range:[]}]

      start_index=index
      [dummy,stop_index]=findPropertyBound(tokens,index+1)
      if stop_index==-1
        throw new Error("Cant find property bound")
      else
        list=tokens.slice(start_index+1,stop_index+1)
        return [
          list.length+2
          [token1,token2,list...]
        ]

      return [1,[token1,token2]]
    else
      token = ['STRING',"'"+String(tokens[index][1])+"'",{range:[]}]
      return [1,[token]]

exprStart= () ->
  tokens=coffee.tokens 'chdl_base.Expr.start()'
  tokens.pop()
  debugExpr+='\nchdl_base.Expr.start()'
  return tokens

exprNext= (n...) ->
  dot       = [ '.',     '.',  {range:[]} ]
  method    = [ 'PROPERTY',    'next',  {range:[]} ]
  callStart = [ 'CALL_START',  '(',     {range:[]} ]
  callEnd   = [ 'CALL_END',     ')',    {range:[]} ]
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

compileExpr=(tokens,i)->
  lineno=tokens[i][2].first_line-headOver
  list =[['IDENTIFIER', '_expr', {range:[]}]]
  [callStart,callEnd]=findCallSlice(tokens,i)
  if callStart>0 and callEnd>0
    extractSlice=tokens.slice(callStart+1,callEnd)
    extractSlice=expandOp(extractSlice)
    exprExpand(extractSlice)
    list.push tokens[callStart]
    #list.push extractSlice...
    skip=0
    for i,index in extractSlice
      if skip>0
        skip-=1
      else
        if i[0] is 'IDENTIFIER' and i[1]=='$'
          [dummy,nextCall]=findCallSlice(extractSlice,index)
          skip=nextCall-index
          list.push compileExpr(extractSlice,index)...
        else
          list.push i
    list.push [',',',',{range:[]}]
    list.push ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
    list.push tokens[callEnd]
    return list
  else
    throw new Error("Can not find call start/end")

expandOp=(tokens)->
  out=[]
  for i,index in tokens
    if i[0]=='IDENTIFIER' and i[1].match(/^\$\w+/)
      m=i[1].match(/^\$(.*)/)
      out.push( ['@', '@', {range:[]}])
      out.push( ['PROPERTY', '_'+m[1], {range:[]}])
    else
      out.push(i)
  return out

patchCode=(text)->
  tokens = coffee.tokens text
  findEqual=(tokens,index)->
    while token=tokens[index]
      if token[0]=='='
        return token
      if token.newLine
        return null
      index+=1
    return null

  patchList=[]
  for i,index in tokens
    if i[0]=='IDENTIFIER' and (i[1]=='consign' or i[1]=='assign' or i[1]=='Net' or i[1]=='Dff')
      lineNum=i[2].first_line
      callPos=i[2].last_column
      if tokens[index+1]?[0]=='CALL_START'
        equalToken=findEqual(tokens,index)
        if equalToken?
          if tokens[index+1].generated
            patchList.push([lineNum,callPos,equalToken[2].first_column])
          else
            patchList.push([lineNum,null,equalToken[2].first_column])
        #else
        #  patchList.push([lineNum,callPos,null])
  lineList=text.split(/\n/)
  for i in patchList
    line = lineList[i[0]]
    charList=[line...]
    if i[1]?
      charList.splice(i[2],1,' ) => $ ')
      charList.splice(i[1]+1,0,'(')
    else
      charList.splice(i[2],1,' => $ ')
    lineList[i[0]]=charList.join('')
  return lineList.join('\n')


extractLogic = (tokens)->
  i = 0
  logicCallPair=[]
  findStartPos=false
  startPos=-1
  endPos=-1
  while token = tokens[i]
    if global.getNoLineno()
      lineno=-1
    else
      lineno=token[2].first_line-headOver
    if token[0] is 'IDENTIFIER' and token[1]=='$'
      [callStart,callEnd]=findCallSlice(tokens,i)
      list=compileExpr(tokens,i)
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='assign'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_assign', {range:[]}]
      ]

      [callStart,callEnd]=findCallSlice(tokens,i)
      patchLength=findAssignBlock(tokens,callEnd)
      tokens.splice(callEnd,0,
        [',',',',{range:[]}],
        ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
      )
      tokens.splice i, 1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='consign'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_consign', {range:[]}]
      ]

      [callStart,callEnd]=findCallSlice(tokens,i)
      patchLength=findAssignBlock(tokens,callEnd)
      tokens.splice(callEnd,0,
        [',',',',{range:[]}],
        ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
      )
      tokens.splice i, 1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='input'
      list =[
        ['IDENTIFIER', 'chdl_base', {range:[]}]
        [ '.',     '.',  {range:[]} ]
        ['PROPERTY', 'input', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Module'
      list =[
        ['IDENTIFIER', 'chdl_base', {range:[]}]
        [ '.',     '.',  {range:[]} ]
        ['PROPERTY', 'Module', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Port'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_port', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Channel'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_channel', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Probe'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_probe', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Monitor'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_monitor', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Wire'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_wire', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='local_wire'
      throw new Error('local_wire is deprecated,use wire')
    #  list =[
    #    ['@', '@', {range:[]}]
    #    ['PROPERTY', '_localWire', {range:[]}]
    #  ]
    #  tokens.splice i, 1, list...
    #  i+=list.length
    else if token[0] is 'IDENTIFIER' and (token[1]=='Net' or token[1]=='Dff')
      sigAssign= do ->
        if token[1]=='Net'
          '_assign'
        else if token[1]=='Dff'
          '_consign'
      sigType = do ->
        if token[1]=='Net'
          '_localWire'
        else if token[1]=='Dff'
          '_localReg'
      netName = tokens[i+2][1]
      [dummy,callEnd]=findCallSlice(tokens,i+1)
      if tokens[i+3][0]==','
        widthArgs=tokens[i+4...callEnd]
        list =[
          ['IDENTIFIER',netName,{range:[]}]
          ['=','=',{range:[]}]
          ['@', '@', {range:[]}]
          ['PROPERTY', sigType, {range:[]}]
          [ 'CALL_START',  '(',     {range:[]} ]
          widthArgs...
          [',',',',{range:[]}]
          ['STRING',"'"+netName+"'",{range:[]}]
          [ 'CALL_END',     ')',    {range:[]} ]
          [ 'TERMINATOR',   '\n',    {range:[]} ]
          ['@', '@', {range:[]}]
          ['PROPERTY', sigAssign, {range:[]}]
          [ 'CALL_START',  '(',     {range:[]} ]
          ['IDENTIFIER',netName,{range:[]}]
          [',',',',{range:[]}],
          ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
          [ 'CALL_END',     ')',    {range:[]} ]
        ]
      else
        list =[
          ['IDENTIFIER',netName,{range:[]}]
          ['=','=',{range:[]}]
          ['@', '@', {range:[]}]
          ['PROPERTY', sigType, {range:[]}]
          [ 'CALL_START',  '(',     {range:[]} ]
          [ 'NUMBER',  '1',     {range:[]} ]
          [',',',',{range:[]}]
          ['STRING',"'"+netName+"'",{range:[]}]
          [ 'CALL_END',     ')',    {range:[]} ]
          [ 'TERMINATOR',   '\n',    {range:[]} ]
          ['@', '@', {range:[]}]
          ['PROPERTY', sigAssign, {range:[]}]
          [ 'CALL_START',  '(',     {range:[]} ]
          ['IDENTIFIER',netName,{range:[]}]
          [',',',',{range:[]}],
          ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
          [ 'CALL_END',     ')',    {range:[]} ]
        ]
      patchLength=findAssignBlock(tokens,callEnd)
      tokens.splice i, callEnd-i+1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='local_reg'
      throw new Error('local_reg is deprecated,use reg')
    #  list =[
    #    ['@', '@', {range:[]}]
    #    ['PROPERTY', '_localReg', {range:[]}]
    #  ]
    #  tokens.splice i, 1, list...
    #  i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Reg'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_reg', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='Mem'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_mem', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='CellMap'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_cellmap', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    #else if token[0] is 'IDENTIFIER' and token[1]=='Hub'
    #  list =[
    #    ['@', '@', {range:[]}]
    #    ['PROPERTY', '_hub', {range:[]}]
    #  ]
    #  tokens.splice i, 1, list...
    #  i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='output'
      list =[
        ['IDENTIFIER', 'chdl_base', {range:[]}]
        [ '.',     '.',  {range:[]} ]
        ['PROPERTY', 'output', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='GlobalModule'
      list =[
        ['IDENTIFIER', 'chdl_base', {range:[]}]
        [ '.',     '.',  {range:[]} ]
        ['PROPERTY', 'buildGlobalModule', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='CompanyModule'
      list =[
        ['IDENTIFIER', 'chdl_base', {range:[]}]
        [ '.',     '.',  {range:[]} ]
        ['PROPERTY', 'buildCompanyModule', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='vec'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_localVec', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='bind'
      list =[
        ['IDENTIFIER', 'chdl_base', {range:[]}]
        [ '.',     '.',  {range:[]} ]
        ['PROPERTY', 'bind', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='reg'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_localReg', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='vreg'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_localVreg', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='channel'
      list =[
        ['IDENTIFIER', 'chdl_base', {range:[]}]
        [ '.',     '.',  {range:[]} ]
        ['PROPERTY', 'channel', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='wire'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_localWire', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='unpack_wire'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_localUnpackWire', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='importDesign'
      list =[
        ['IDENTIFIER', '_importLib', {range:[]}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      tokens.splice(callEnd,0,
        [',',',',{range:[]}],
        ['IDENTIFIER', '__dirname', {range:[]}]
      )
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='importLib'
      list =[
        ['IDENTIFIER', '_importLib', {range:[]}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      tokens.splice(callEnd,0,
        [',',',',{range:[]}],
        ['IDENTIFIER', '__dirname', {range:[]}]
      )
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='always'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_always', {range:[]}]
      ]
      patchLength=findAlwaysBlock(tokens,i,lineno)
      tokens.splice i, 1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='always_if'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_always_if', {range:[]}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push [',',',',{range:[]}]
      list.push ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
      list.push tokens[callEnd]
      patchLength=findCondBlock(tokens,callEnd)
      tokens.splice i, callEnd-i+1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='forever'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_forever', {range:[]}]
      ]
      patchLength=findAlwaysBlock(tokens,i,lineno)
      tokens.splice i, 1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='initial'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_initial', {range:[]}]
      ]
      patchLength=findAlwaysBlock(tokens,i)
      tokens.splice i, 1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='Mixin'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_mixin', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='MixinAs'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_mixinas', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$sequence'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_sequenceDef', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$while'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_while', {range:[]}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push [',',',',{range:[]}]
      list.push ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
      list.push tokens[callEnd]
      patchLength=findCondBlock(tokens,callEnd)
      tokens.splice i, callEnd-i+1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='$if_blocks'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_if_blocks', {range:[]}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$if'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_if', {range:[]}]
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
          ['.', '.', {range:[]}]
          ['PROPERTY', '_endif', {range:[]}]
          [ 'CALL_START',  '(',     {range:[]} ]
          [ 'CALL_END',     ')',    {range:[]} ]
        ]
        tokens.splice outdentIndex+1, 0, append_list...
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push [',',',',{range:[]}]
      list.push ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
      list.push tokens[callEnd]
      patchLength=findCondBlock(tokens,callEnd)
      tokens.splice i, callEnd-i+1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='$elseif'
      list =[
        ['.', '.', {range:[]}] ,
        ['PROPERTY', '_elseif', {range:[]}]
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
          ['.', '.', {range:[]}]
          ['PROPERTY', '_endif', {range:[]}]
          [ 'CALL_START',  '(',     {range:[]} ]
          [ 'CALL_END',     ')',    {range:[]} ]
        ]
        tokens.splice outdentIndex+1, 0, append_list...
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push [',',',',{range:[]}]
      list.push ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
      list.push tokens[callEnd]
      patchLength=findCondBlock(tokens,callEnd)
      tokens.splice i, callEnd-i+1, list...
      i+=list.length+patchLength
    else if token[0] is 'IDENTIFIER' and token[1]=='$else'
      list =[
        ['.', '.', {range:[]}]
        ['PROPERTY', '_else', {range:[]}]
        ['CALL_START', '(', {range:[]}]
        ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
        ['CALL_END',  ')', {range:[]} ]
      ]
      if tokens[i+1][0]=='CALL_START'
        [dummy,outdentIndex]=findCallSlice(tokens,i+1)
      else
        [dummy,outdentIndex]=findIndentSlice(tokens,i+1)
      unless tokens[outdentIndex+1][0]=='TERMINATOR' and  tokenIsEndIf(tokens,outdentIndex+2)
        append_list=[
          ['.', '.', {range:[]}]
          ['PROPERTY', '_endif', {range:[]}]
          [ 'CALL_START',  '(',     {range:[]} ]
          [ 'CALL_END',     ')',    {range:[]} ]
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
        ['.', '.', {range:[]}]
        ['PROPERTY', '_endif', {range:[]}]
        [ 'CALL_START',  '(',     {range:[]} ]
        [ 'CALL_END',     ')',    {range:[]} ]
      ]
      if tokens[i-1][0]=='TERMINATOR'
        tokens.splice i-1, 1
        i--
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$cond'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_cond', {range:[]}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      if tokens[callEnd+1][0]!='CALL_START'
        append_list=[
          ['CALL_START',"(",{range:[]}]
          ['NULL',"null",{range:[]}]
          ['CALL_END',")",{range:[]}]
        ]
        tokens.splice callEnd+1, 0, append_list...
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      if extractSlice.length==0
        list.push ['NULL',"null",{range:[]}]
      else
        list.push extractSlice...
      list.push [',',',',{range:[]}]
      list.push ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
      list.push tokens[callEnd]
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$lazy_cond'
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_lazy_cond', {range:[]}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      if tokens[callEnd+1][0]!='CALL_START'
        append_list=[
          ['CALL_START',"(",{range:[]}]
          ['NULL',"null",{range:[]}]
          ['CALL_END',")",{range:[]}]
        ]
        tokens.splice callEnd+1, 0, append_list...
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      if extractSlice.length==0
        list.push ['NULL',"null",{range:[]}]
      else
        list.push extractSlice...
      list.push [',',',',{range:[]}]
      list.push ['NUMBER',"'"+String(lineno)+"'",{range:[]}]
      list.push tokens[callEnd]
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1].match(/^\$/)
      m=token[1].match(/^\$(.*)/)
      list =[
        ['@', '@', {range:[]}]
        ['PROPERTY', '_'+m[1], {range:[]}]
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
        list=exprNext(['STRING',"'begin'",{range:[]}])
        tokens.splice i, 1, list...
        i+=list.length
      else if token[0] is 'OUTDENT'
        list=exprNext(['STRING',"'end'",{range:[]}])
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
        list=exprNext(['STRING',"'begin'",{range:[]}])
        tokens.splice i, 1, list...
        i+=list.length
      else if token[0] is 'OUTDENT'
        list=exprNext(['STRING',"'end'",{range:[]}])
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

pushToReload=(s,type='user')->
  reloadList.push({path:s,type:type})

cleanCache= ->
  for i in reloadList
    delete require.cache[i.path]
  reloadList=[]

buildCode= (fullFileName,text,debug=false,param=[]) ->
  cleanCache()
  design=transToJs(fullFileName,text,debug)
  return chdl_base.toVerilog(new design(param...))

buildLib= (fullFileName,text,debug=false,param=null) ->
  transToJs(fullFileName,text,debug)

transToJs= (fullFileName,text,debug=false) ->
  md5Sign = md5(text)
  if global.getForce()==false and fs.existsSync(fullFileName+'.js')
    signStr=fs.readFileSync(fullFileName+'.js','utf8').substr(0,38)
    if signStr.substr(0,6)=='\/\/md5 '
      if md5Sign==signStr.substr(6,32)
        return require("#{fullFileName}.js")
  log "Genarate #{fullFileName}.js"
  text=patchCode(text)
  #console.log text
  head = "chdl_base = require 'chdl_base'\n"
  head +="{_expr}=require 'chdl_utils'\n"
  head +="{cat,expand,all1,all0,has0,has1,hasOdd1,hasEven1}=require 'chdl_operator'\n"
  head += "{infer,hex,oct,bin,dec}= require 'chdl_base'\n"
  head += "global = require('chdl_global')\n"
  head += "{_importLib}= require 'chdl_transpiler_engine'\n"
  head += "module.paths.push('#{process.cwd()}')\n"
  text = head + text
  text+="\nreturn module.exports"
  tokens = coffee.tokens text
  if debug
    log "========================="
    log "origin Tokens"
    log "========================="
    log i for i in tokens
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
  javaScript="\/\/md5 #{md5Sign}\n"+javaScript
  fs.writeFileSync("#{fullFileName}.js", javaScript,'utf8')
  pushToReload("#{fullFileName}.js")
  return require("#{fullFileName}.js")

importLib=(path,dirname)->
  if path.match(/^\./)
    fullName = Path.resolve(dirname+'/'+path.replace(/\.chdl$/,'')+'.chdl')
    if fs.existsSync(fullName)
      text=fs.readFileSync(fullName, 'utf-8')
      module.paths.push Path.dirname(fullName)
      return transToJs(fullName,text,false)
    throw new Error("Cant find file "+fullName)
  else if Path.isAbsolute(path)
    fullName= Path.resolve(path.replace(/\.chdl$/,'')+'.chdl')
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
      if Path.extname(path)=='.chdl'
        chdlFullName=Path.resolve(i+'/'+path)
        jsFullName=Path.resolve(i+'/'+path+'.js')
        if fs.existsSync(chdlFullName) and (not fs.existsSync(jsFullName))
          text=fs.readFileSync(chdlFullName, 'utf-8')
          transToJs(chdlFullName,text,false)
        fullName=jsFullName
      else
        fullName= Path.resolve(i+'/'+path)
      if fs.existsSync(fullName)
        pushToReload(fullName,'sys')
        return require(fullName)
        #text=fs.readFileSync(fullName, 'utf-8')
        #return transToJs(fullName,text,false)
    throw new Error("Cant find file "+path)

expandNum=(tokens)->
  out=[]
  skip=0
  for i,index in tokens
    if skip>0
      skip-=1
    else if i[0]=='NUMBER' and tokens[index+1]?[0]=='STRING' and tokens[index+1]?[1].match(/^"[hdob][0-9a-fA-F_]+"/)
      chars=[tokens[index+1][1]...]
      chars=_.initial(chars)
      chars=_.tail(chars)
      head=chars[0]
      chars=_.tail(chars)
      numFormat='hex'
      prefix=''
      if head=='h'
        numFormat='hex'
        prefix='0x'
      else if head=='o'
        numFormat='oct'
        prefix='0o'
      else if head=='b'
        numFormat='bin'
        prefix='0b'
      else if head=='d'
        numFormat='dec'
      newTokens=[
        [
          "IDENTIFIER",
          "#{numFormat}",
          {range:[]}
        ],
        [
          "CALL_START",
          "(",
          {range:[]}
        ],
        [
          "NUMBER",
          "#{tokens[index][1]}",
          {range:[]}
        ],
        [
          ",",
          ",",
          {range:[]}
        ],
        [
          "STRING",
          "'"+prefix+chars.join('')+"'",
          {range:[]}
        ],
        [
          "CALL_END",
          ")",
          {range:[]}
        ]
      ]
      out.push newTokens...
      skip=1
    #else if i[0]=='NUMBER' and tokens[index+1]?[0]=='\\' and tokens[index+2]?[1].match(/^[hdob]/)
    #  numFormat='hex'
    #  prefix=''
    #  if tokens[index+2][1][0]=='h'
    #    numFormat='hex'
    #    prefix='0x'
    #  else if tokens[index+2][1][0]=='o'
    #    numFormat='oct'
    #    prefix='0o'
    #  else if tokens[index+2][1][0]=='b'
    #    numFormat='bin'
    #    prefix='0b'
    #  else if tokens[index+2][1][0]=='d'
    #    numFormat='dec'
    #  newTokens=[
    #    [
    #      "IDENTIFIER",
    #      "#{numFormat}",
    #      {range:[]}
    #    ],
    #    [
    #      "CALL_START",
    #      "(",
    #      {range:[]}
    #    ],
    #    [
    #      "NUMBER",
    #      "#{tokens[index][1]}",
    #      {range:[]}
    #    ],
    #    [
    #      ",",
    #      ",",
    #      {range:[]}
    #    ],
    #    [
    #      "STRING",
    #      "'"+prefix+tokens[index+2][1][1...]+"'",
    #      {range:[]}
    #    ],
    #    [
    #      "CALL_END",
    #      ")",
    #      {range:[]}
    #    ]
    #  ]
    #  out.push newTokens...
    #  skip=2
    else
      out.push(i)
  return out

module.exports.buildCode= buildCode
module.exports.buildLib= buildLib
module.exports.setPaths= (paths)=>
  module.paths=(i for i in paths)
module.exports._importLib= importLib
module.exports.compiledFileList = ()=>
  reloadList
module.exports.headOver = headOver


