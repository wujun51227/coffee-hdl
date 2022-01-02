0.7升级到0.7.1版本有不向前兼容的更新，
```csv-text
  0.7版本模块api函数,0.7.1版本的方式
  target_width()       , assignee_width()
```

0.6升级到0.7版本有不向前兼容的更新，

  * 移除了一些模块级api函数，使用Property()方法申明模块属性，并增加了一些全局函数，如下所示
 

```csv-text
  0.6版本模块api函数,0.7版本的方式
  @moduleParameter()   , Property.module_parameter
  @instParameter()     , Property.override_parameter
  @specifyModuleName() , Property.module_name
  @setLint()           , Property.(lint_width_check_overflow| lint_width_check_mismatch| lint_width_check_disable)
  @setCombModule()     , Property.comb_module
  @notUniq()           , Property.uniq_name
  @setDefaultClock()   , Property.default_clock
  @setDefaultReset()   , Property.default_reset
  @setBlackBox()       , Property.blackbox
  @mold()              , mold()
  @display()           , display()
  @verilog()           , verilog()
  @targetWidth()       , target_width()
  @getParameter()      , get_parameter()
```


示例，0.6版本写法
```coffeescript
  @setDefaultClock('clk')
  @setDefaultReset('rstn')
```
 
0.7以上版本写法
```coffeescript
 Property(
   default_clock: 'clk'
   default_reset: 'rstn'
 )
```

* 去除了testbench里面的行为级$sequence用法, 增加了$flow函数实现可阻塞的次序操作
 
 在$flow函数中你可以像在verilog一样使用阻塞操作，列表如下

```csv-text
 操作, 描述
 go n                   , 延时 n 纳秒，n可以是小数
 posedge/negedge signal , 等待信号上升/下降沿
 polling signal expr    , 使用signal采样表达式expr直到为真
 wait expr              , 等待表达式expr为真
 event event_name             , 发送事件
 trigger event_name           , 等待事件触发
```
 
示例，0.6版本写法
```coffeescript
 initial
   $sequence()
   .init =>
     assign a = 1
   .delay(10) =>
     assign a = 0
   .posedge(@clk) =>
     assign a = 1
   .wait($(aa==bb)) =>
     assign a = 0
   .end()
```
 
0.7以上版本写法

```coffeescript
 initial
   $flow =>
     assign a = 1
     go 10
     assign a = 0
     posedge @clk
     assign a = 1
     wait $(aa==bb)
     assign a = 0
```

