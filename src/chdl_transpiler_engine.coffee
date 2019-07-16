do ->
  libEnv= require('process').env.CHDL_LIB
  if libEnv?
    list=libEnv.split(/:/)
    module.paths.push list...

coffee = require 'coffeescript'
_ = require 'lodash'
log = require 'fancy-log'
{printBuffer}=require 'chdl_utils'

debugExpr=''

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

findPipeRegSlice=(tokens,index)->
  i=index
  cnt=0
  start=-1
  while token = tokens[i]
    if token[0]=='{' and tokens[i-1]?[0]=='{'
      if start==-1
        start=i
      cnt++
    else if token[0]=='}' and tokens[i+1]?[0]=='}'
      cnt--
      if cnt==0
        return [start,i]
    i++
  return [start,-1]

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

scanToken= (tokens,index)->
  ret=[]
  #console.log '>>>>>>tokens',index,tokens[index...]
  nativeItem = tokens[index][0]=='@' and tokens[index+1]?[0]=='PROPERTY'
  catFunc = tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='cat' and tokens[index+1]?[0]=='CALL_START'
  channelFunc = tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='channel_wire' and tokens[index+1]?[0]=='CALL_START'
  #constValue= tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='__v' and tokens[index+1]?[0]=='CALL_START'
  toHex= tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='hex' and tokens[index+1]?[0]=='CALL_START'
  toDec= tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='dec' and tokens[index+1]?[0]=='CALL_START'
  toOct= tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='oct' and tokens[index+1]?[0]=='CALL_START'
  toBin= tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='bin' and tokens[index+1]?[0]=='CALL_START'
  #constValue= tokens[index][0]=='@' and tokens[index+1]?[0]=='CALL_START'
  isHex = tokens[index][0]=='NUMBER' and tokens[index][1].match(/^0x/)
  isOct= tokens[index][0]=='NUMBER' and tokens[index][1].match(/^0o/)
  isBin= tokens[index][0]=='NUMBER' and tokens[index][1].match(/^0b/)
  isDec= tokens[index][0]=='NUMBER' and tokens[index][1].match(/^[1-9]/)
  getIndex=false
  if tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='eval'
    cnt=0
    i=index
    while token = tokens[i]
      ret.push(token)
      if token[0]=='CALL_START'
        cnt++
      else if token[0]=='CALL_END'
        cnt--
        if cnt==0
          return [ret.length,ret]
      i++
  else if tokens[index][0]=='IDENTIFIER' and tokens[index][1]=='$local'
    cnt=0
    i=index+1
    while token = tokens[i]
      if token[0]=='CALL_START'
        cnt++
      else if token[0]=='CALL_END'
        cnt--
        if cnt==0
          return [ret.length+3,ret]
      else
        ret.push(token)
      i++
  else if tokens[index][0]=='{'
    i=index
    cnt=0
    list=[]
    while token = tokens[i]
      list.push token
      if token[0]=='{'
        cnt++
      else if token[0]=='}'
        cnt--
        if cnt==0
          return [list.length,list.slice(1,list.length-1)]
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
  else if toHex or toDec or toOct or toBin
    numberToken=tokens[index+4]
    if numberToken[0]=='NUMBER'
      numberToken[0]='STRING'
      numberToken[1]="'"+String(numberToken[1])+"'"
    cnt=0
    ret.push tokens[index]
    i=index+1
    while token = tokens[i]
      if token[0]=='CALL_START'
        ret.push token
        cnt++
      else if token[0]=='CALL_END'
        ret.push token
        cnt--
        if cnt==0
          return [ret.length,ret]
      else
        ret.push(token)
      i++
  else if nativeItem or channelFunc
    if channelFunc
      list=[tokens[index]]
      start_index=index
      stop_index=index
    else
      list=[tokens[index],tokens[index+1]]
      start_index=index
      index++
      stop_index=index
    timeout_cnt=0
    while tokens[index]?
      timeout_cnt+=1
      break if timeout_cnt>100

      if tokens[index+1]?[0]=='.'
        cursor=index+1
        if tokens[cursor][0]=='.' and tokens[cursor+1][0]=='PROPERTY'
          list.push tokens[cursor]
          list.push tokens[cursor+1]
          stop_index=cursor+1
          index=stop_index
          cursor+=2
      else if tokens[index+1]?[0]=='CALL_START'
        cursor=index+1
        cnt=0
        while token = tokens[cursor]
          list.push token
          if token[0]=='CALL_START'
            cnt++
          else if token[0]=='CALL_END'
            cnt--
            if cnt==0
              stop_index=cursor
              index=stop_index
              break
          cursor++
      else if tokens[index+1]?[0]=='INDEX_START'
        cursor=index+1
        cnt=0
        while token = tokens[cursor]
          list.push token
          if token[0]=='INDEX_START'
            cnt++
          else if token[0]=='INDEX_END'
            cnt--
            if cnt==0
              stop_index=cursor
              index=stop_index
              break
          cursor++
      else
        break
    if channelFunc
      list[0][0]='PROPERTY'
      list[0][1]='_getChannelWire'
      list.unshift ['@','@',{}]
    return [
      stop_index-start_index+1
      list
    ]
  else if catFunc
    start_index=index
    [dummy,stop_index]=findCallSlice(tokens,index+1)
    list=tokens.slice(start_index,stop_index+1)
    return [
      list.length
      list
    ]
  else if tokens[index][0]=='STRING'
    token = ['STRING',String(tokens[index][1]),{}]
    return [1,[token]]
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

extractLogic = (tokens)->
  i = 0
  logicCallPair=[]
  findStartPos=false
  startPos=-1
  endPos=-1
  while token = tokens[i]
    #console.log '>>>>>',token[0],token[1]
    if token[0] is 'IDENTIFIER' and token[1]=='$'
      list =[ ['@', '@', {}] ,['PROPERTY', '_expr', {}]]
      [callStart,callEnd]=findCallSlice(tokens,i)
      extractSlice=tokens.slice(callStart+1,callEnd)
      exprExpand(extractSlice)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push tokens[callEnd]
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='assign_pipe'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_assignPipe', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='assign'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_assign', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
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
    else if token[0] is 'IDENTIFIER' and token[1]=='Hub'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_hub', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
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
        ['IDENTIFIER', 'chdl_base', {}]
        [ '.',     '.',  { } ]
        ['PROPERTY', 'reg', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='behave_reg'
      list =[
        ['IDENTIFIER', 'chdl_base', {}]
        [ '.',     '.',  { } ]
        ['PROPERTY', 'behave_reg', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='channel'
      list =[
        #['IDENTIFIER', 'chdl_base', {}]
        #[ '.',     '.',  { } ]
        ['@', '@', {}]
        ['PROPERTY', '_newChannel', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='channel_wire'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_getChannelWire', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='wire'
      list =[
        ['IDENTIFIER', 'chdl_base', {}]
        [ '.',     '.',  { } ]
        ['PROPERTY', 'wire', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='importDesign'
      list =[
        ['IDENTIFIER', 'chdl_base', {}]
        [ '.',     '.',  { } ]
        ['PROPERTY', 'importDesign', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='always'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_always', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    #else if token[0] is 'IDENTIFIER' and token[1]=='latch'
    #  list =[
    #    ['@', '@', {}]
    #    ['PROPERTY', '_latch', {}]
    #  ]
    #  tokens.splice i, 1, list...
    #  i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='pipeline'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_pipeline', {}]
      ]
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$balance'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_caseProcess', {}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push tokens[callEnd]
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$expand'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_expandProcess', {}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push tokens[callEnd]
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$order'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_orderProcess', {}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push tokens[callEnd]
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$cond'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_cond', {}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push tokens[callEnd]
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$default'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_default', {}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push tokens[callEnd]
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$if'
      list =[
        ['@', '@', {}]
        ['PROPERTY', '_if', {}]
      ]
      [callStart,callEnd]=findCallSlice(tokens,i)
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push tokens[callEnd]
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$elseif'
      list =[ ['.', '.', {}] ,['PROPERTY', '_elseif', {}]]
      if tokens[i-1][0]=='TERMINATOR'
        tokens.splice i-1, 1
        i--
      [callStart,callEnd]=findCallSlice(tokens,i)
      extractSlice=tokens.slice(callStart+1,callEnd)
      tokenExpand(extractSlice,true)
      list.push tokens[callStart]
      list.push extractSlice...
      list.push tokens[callEnd]
      tokens.splice i, callEnd-i+1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$else'
      list =[
        ['.', '.', {}]
        ['PROPERTY', '_else', {}]
      ]
      if tokens[i-1][0]=='TERMINATOR'
        tokens.splice i-1, 1
        i--
      tokens.splice i, 1, list...
      i+=list.length
    else if token[0] is 'IDENTIFIER' and token[1]=='$endif'
      list =[
        ['.', '.', {}]
        ['PROPERTY', '_endif', {}]
      ]
      if tokens[i-1][0]=='TERMINATOR'
        tokens.splice i-1, 1
        i--
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

getWidth = (number)->
  if Number(number)==0
    return 1
  else
    Math.floor(Math.log2(Number(number))+1)

hex = (n,m=null)->
  if m==null
    w=getWidth(n)
    __v(w,'0x'+(n>>>0).toString(16))
  else
    __v(n,'0x'+(m>>>0).toString(16))

dec= (n,m=null)->
  if m==null
    w=getWidth(n)
    __v(w,n>>>0)
  else
    __v(n,m>>>0)

oct= (n,m=null)->
  if m==null
    w=getWidth(n)
    __v(w,'0o'+(n>>>0).toString(8))
  else
    __v(n, '0o'+(m>>>0).toString(8))

bin= (n,m=null)->
  if m==null
    w=getWidth(n)
    __v(w,'0b'+(n>>>0).toString(2))
  else
    __v(n, '0b'+(m>>>0).toString(2))

__v=(widthIn,number)->
  width=if widthIn? then widthIn else getWidth(number)

  if _.isString(number)
    if number.match(/^0x/)
      m=number.match(/^0x(.*)/)
      return "#{width}'h#{m[1]}"
    else if number.match(/^0o/)
      m=number.match(/^0o(.*)/)
      return "#{width}'o#{m[1]}"
    else if number.match(/^0b/)
      m=number.match(/^0b(.*)/)
      return "#{width}'b#{m[1]}"
    else
      if width=='1' or width==1
        return "1'b#{number}"
      else if width==''
        return "#{number}"
      else
        return "#{width}'d#{number}"
  else if _.isNumber(Number(number))
    if width==''
      return "#{number}"
    else if width=='1' or width==1
      return "1'b#{number}"
    else
      return "#{width}'d#{number}"
  else
    throw new Error("const value error")

getValue=(i)=>
  if _.isString(i)
    return i
  if _.isNumber(i)
    return i
  if i.constructor?.name=='Expr'
    return i.str
  if i.constructor?.name=='Port'
    return i.refName()
  if i.constructor?.name=='Wire'
    return i.refName()
  if i.constructor?.name=='Reg'
    return i.refName()
  if i.constructor?.name=='BehaveReg'
    return i.refName()
  if _.isFunction(i)
    return i().refName()
  throw new Error('arg type error'+i)

cat= (args...)->
  if args.length==1 and _.isPlainObject(args[0])
    list=_.map(_.sortBy(_.entries(args[0]),(i)=>Number(i[0])),(i)=>getValue(i[1])).reverse()
    return '{'+list.join(',')+'}'
  else if args.length==1 and _.isArray(args[0])
    list=_.map(args[0],(i)=>getValue(i))
    return '{'+list.join(',')+'}'
  else
    list=_.map(args,(i)=>getValue(i))
    return '{'+list.join(',')+'}'

transToVerilog= (text,debug=false,param='') ->
  head = "chdl_base = require 'chdl_base'\n"
  head += "{op_reduce}= require 'chdl_base'\n"
  text = head + text
  #console.log ">>>>",module.paths
  text+="\n__dut__=module.exports"
  text+="\nchdl_base.toVerilog(new __dut__(#{param}))"
  tokens = coffee.tokens text
  if debug
    log ">>>>>>origin Tokens\n"
    for token in tokens
      log token[0],token[1]
  extractLogic(tokens)
  options={
    referencedVars : ( token[1] for token in tokens when token[0] is 'IDENTIFIER')
    bare:false
  }

  if debug
    log ">>>>>>extract Tokens\n"
    for token in tokens
      log token[0],token[1]
    log '>>>>>expr ',debugExpr
  nodes = coffee.nodes tokens
  fragments=nodes.compileToFragments options
  javaScript = ''
  for fragment in fragments
    javaScript += fragment.code
  log ">>>>>>Javascript\n",javaScript if debug
  printBuffer.reset()
  eval javaScript
  return javaScript

transToJs= (text,debug=false) ->
  head = "chdl_base = require 'chdl_base'\n"
  head += "{op_reduce}= require 'chdl_base'\n"
  text = head + text
  text+="\n__dut__=module.exports"
  text+="\nreturn __dut__"
  tokens = coffee.tokens text
  if debug
    log ">>>>>>origin Tokens\n"
    for token in tokens
      log token[0],token[1]
  extractLogic(tokens)
  options={
    referencedVars : ( token[1] for token in tokens when token[0] is 'IDENTIFIER')
    bare:false
  }

  if debug
    log ">>>>>>extract Tokens\n"
    for token in tokens
      log token[0],token[1]
    log '>>>>>expr ',debugExpr
  nodes = coffee.nodes tokens
  fragments=nodes.compileToFragments options
  javaScript = ''
  for fragment in fragments
    javaScript += fragment.code
  log ">>>>>>Javascript\n",javaScript if debug
  return eval(javaScript)

module.exports.transToVerilog = transToVerilog
module.exports.transToJs= transToJs
module.exports.setPaths= (paths)=>
  module.paths=(i for i in paths)
module.exports.getPaths= ()=> module.paths


