# coffee-hdl 用户手册 v0.1
##  介绍

本文档是coffee-hdl(coffeescript hardware description language)的使用手册.coffee-hdl是嵌入在coffeescript编程语言中的硬件构造语言,是一种对coffeescript语言做了词法编译的改造扩充后的DSL,所以当您编写coffee-hdl时,实际上是在编写构造硬件电路的coffeescript程序.作者并不假定您是否了解如何在coffeescript中编程,我们将通过给出的例子指出必要的coffee-hdl语法特性,大多数的硬件设计可以使用本文中包含的语法来完成.在1.0版本到来之前,还会有功能增加和语法修改，所以不保证后继版本向下兼容.

对于宿主语言coffeescript 我们建议您花费几个小时浏览[coffeescript.org](https://coffeescript.org)来学习coffeescript的基本语法,coffeescript是一门表达能力很强但是又非常简单的动态语言,最终编译器会翻译成javascript语言通过nodejs引擎运行, 进一步的学习请参考一本优秀的coffeescript书籍 ["coffeescript in action"](https://www.manning.com/books/coffeescript-in-action).

##  安装
coffee-hdl需要nodejs v8以上环境支持以及2.0以上版本的coffeescript编译器支持,如果操作系统没有自带nodejs环境,请在 https://nodejs.org/en/download/ 下载相应版本,解压缩以后把path指向nodejs安装目录的bin目录就可以了.

coffee-hdl安装步骤

		git clone git@github.com:wujun51227/coffee-hdl.git
		cd coffee-hdl
		npm install #or yarn install
		source sourceme.sh
		cd test
		./run.bash

##  设计目标
coffee-hdl关注二进制逻辑设计,能表达所有的verilog时序电路和组合电路,包括多时钟,同步异步复位,带延迟的非阻塞赋值,时钟门控结构,请把coffee-hdl当作语义化的rtl描述语言,而不是高级抽象描述语言.coffee-hdl的设计目标按优先级排列如下:

	* 语义化表达电路结构
	* 方便模块集成和互联
	* 语义化指导综合等流程工具
	* 对verilog互动友好,生成代码可读性良好,易于debug
	* 强调参数化设计,动态生成verilog描述,彻底去除在verilog中使用define条件编译
	* 仿真器中立,对功能验证提供高层次的支持
	
coffee-hdl的未来要实现的功能
	
	* 使用宿主语言coffeescript仿真
	* 对firrtl支持

## 文件类型和模块
coffeescript-hdl模块描述文件以.chdl作为文件后缀名,一个模块一个文件,导入模块
使用importDesign(file_name),  其中file_name可以省略.chdl后缀名,如果导入普通coffeescript模块,使用标准的require方式导入,值得注意的是,导入路径的基本路径是顶层模块所在的目录.

模块内容一般是三部分组成
1. 实例化子模块
2. 在构造函数内申明port,wire,channel,reg等资源,并且绑定channel到cell的端口
3. 在build函数内描述模块的数字逻辑,主要是assign,assign_pipe等语句构成

示例代码(test/integration/import_simple.chdl),语法细节请参见后面的介绍

```coffeescript
cell1 = importDesign('./cell1.chdl')  #引入子模块

class ImportSimple extends Module     #申明当前模块
  u0_cell1: new cell1()               #例化子模块

  constructor: ->
    super()
    Port(                             #端口申明
      bindBundle: bind('up_signal')   #绑定通道
      clock: input().asClock()        #输入时钟信号
      rstn: input().asReset()         #输入复位信号
    )

    Reg(
      data_latch: reg(16)            #申明寄存器
    )

    Wire(
      data_wire: wire(16)           #申明线
    )

    @u0_cell1.bind(
      bundle: channel 'up_signal'   #通道和例化模块端口对接
    )

  build: ->                         #模块内部数字逻辑
    assign(@data_wire) => $ channel_wire('up_signal','din')+1

    always =>
      assign(@data_latch) => $ @data_wire*2

module.exports=ImportSimple
```
生成代码
```verilog
`ifndef UDLY
`define UDLY 1
`endif
module ImportSimple__1(
  input clock,
  input rstn,
  input [15:0] bindBundle__din,
  output [15:0] bindBundle__dout
);
//wire declare
wire [15:0] data_wire;
wire [15:0] up_signal__din;
wire [15:0] up_signal__dout;
//port wire declare
wire clock;
wire rstn;
wire [15:0] bindBundle__din;
wire [15:0] bindBundle__dout;
//register declare
//register init and update
reg [15:0] data_latch;
reg [15:0] _data_latch;
always @(posedge clock or negedge rstn) begin
  if(!rstn) begin
    data_latch <= #`UDLY 0;
  end
  else begin
    data_latch <= #`UDLY _data_latch;
  end
end

//channel declare
//pipeline declare
//assign logic
assign up_signal__din = bindBundle__din;
assign bindBundle__dout = up_signal__dout;
assign data_wire = up_signal__din+1'b1;
//register update logic
always_comb begin
  _data_latch=data_latch;
  _data_latch = data_wire*2'd2;
end

//datapath logic
//cell instance
cell1 u0_cell1(
  .bundle__din( up_signal__din),
  .bundle__dout( up_signal__dout),
  .clock( clock ),
  .rstn( rstn )
);

endmodule
```

##  数值字面量
coffee-hdl数值字面量指保存在wire或者reg的bit值,在coffee-hdl里面不支持X态和Z态,只有0和1两种状态,数值字面量一般带有宽度信息.

在coffee-hdl中,用电路表达的数据类型沿用verilog的表达形式,用全局函数hex/oct/bin/dec(width,value)生成verilog中的字面量数字,如果使用coffeescript基本整数类型,则自动计算位宽信息,位宽计算方式遵守verilog规则.示例代码如下(test/data_type/const_data.chdl)

		hex(12,0x123) // 12'h123
		hex(0x123)    // 9'h123
		hex(123)      // 7'h7b
		bin(9,12)     // 9'b1100
		oct(12, 123)  // 7'o173
		0x123         // 9'h123
		0b1100        // 4'b1100

字符串,对象等数据类型无法在电路描述层面使用,但是可以在宿主程序计算的时候影响电路生成的形式

## 组合电路表达
coffee-hdl采用“$”符号作为verilog组合电路表达式的前导符,凡是跟在"$"符号后面
的表达式都会产生相应的的verilog组合电路表达式,其中有几个限制需要注意
* 可以用 @name 的方式直接引用模块内部的wire,reg等资源
* 需有求值的部分必须放在{}中,比如局部变量,原生数据计算等等
* 除此以外的符号都按照字面量生成在verilog表达式当中
* 三目运算符的:符号无法支持,必须使用双引号以":"的方式保留
* 由于{}符号作为求值运算符存在,verilog原生的{}运算符的使用cat()函数代替 

示例代码 (test/express/expr_simple.chdl)
```coffeescript
build: ->
  data=100
  assign(@out) => $ @sel ? {data+1} ":" hex(5,0x1f)
```
生成代码
```verilog
assign out = sel?101:5'h1f;
```
## assign语句
coffee-hdl的组合电路信号传递通过assign语句生成,表达方式为assign(signal) => block, signal为申明的reg/wire,block为一个函数,函数的返回值必须是$表达式产生的verilog语句
	
在coffee-hdl中,可以写出如下代码表达组合电路信号传递

示例代码 (test/control/branch_test.chdl)
```coffeescript
assign(@dout) =>
  $if(@sel1)     =>    $ @din+1
  $elseif(@sel2) =>    $ @din+2
  $elseif(@sel3) =>    $ @din+3
  $else          =>    $ @din
  $endif()
```

生成代码

```verilog
dout = (sel1)?din+1:(sel2)?din+2:(sel3)?din+3:din;
```

请注意dout信号始终保持wire语义,而不必像verilog在使用if else的情况下需要把wire声明成reg,模块中申明的reg类型都是真实的寄存器

无优先级并行电路可以使用$balance/$cond语句,前提是程序员需要保证cond1,cond2互斥

示例代码(test/control/branch_test.chdl)

```coffeescript
assign(@out) =>
   $balance(@out.getWidth()) [                                      
    $cond(@cond1) => $ @data1                                           
    $cond(@cond2) => $ @data2                                           
  ] 
```
生成代码
```verilog
assign out = (16{cond1}&(data1))|
            (16{cond2}&(data2));
```

如果需要批量化产生if elseif else语句,可以使用$order语句

示例代码(test/control/branch_test.chdl)
```coffeescript
assign(@w2.w6) =>
  $order() [
    $cond(@in1(1)) => $ @w2.w3(9:7)
    $cond(@in1(2)) => $ @w2.w3(3:1)
    $default() => $ @w2.w3(6:4)
  ]
```

生成代码
```verilog
assign w2__w6 = (in1[1])?(w2__w3[9:7]):                             
    (in1[2])?(w2__w3[3:1]):                                     
    (w2__w3[6:4]);         
```
通过和coffeescript语言结合,可以基于规格化输入格式生成verilog代码(demo/rsicv32i_decoder.chdl).

## wire 类型
wire类型是用于表达组合电路输出结果的元素,对应生成verilog的wire,但是增加了很多特性,特别式可以申明为数据结构便于编程,最简单声明方式如下
		
```coffeescript
Wire wire_name: wire(width)
```

如果把wire组织成数组,声明方式如下

生成10个16bit宽度线

```coffeescript
Wire( 
    wire_array: wire(16) for i in [0...10]
)
```

或者

把三个10,20,30bit宽度的线组成数组

```coffeescript
Wire(
    wire_array: [
	      wire(10)
	      wire(20)
	      wire(30)
    ]
)
```

数组对象可以通过@wire_array[0]的方式引用

如果把wire组织成map型数据结构,声明方式如下
    
```coffeescript
Wire wire_struct: {
  key1: wire(1)
  package: {
    key2: wire(16)
    }
}
```

map数据结构可以通过@wire_struct.package.key2的方式引用.

wire类型通过()操作符获取bit或者切片,data(1)取bit1,data(3:0)或者data(0,3)取bit[3:0],对于slice或者bit可以设置字段名(setField)使其语义化,

示例代码(test/wire/wire_simple.chdl)
```coffeescript
constructor: ->
  Wire(
    result: wire(33).setField(
      carry: [32,32]
      sum: [31:0]
      )
    )
    
build:->
  assign(@result.field('carry')) => $ 1
  assign(@result.field('sum')) => $ hex(32,0x12345678)
```
生成代码
```verilog
assign result[32] = 1'b1;
assign result[31:0] = 32'h12345678;
```
wire类型带有以下常用方法
	* reverse() 高低位逆序排列
	* select( (index)=> func) 根据函数式取得wire相应bit组成新的wire
示例代码(test/wire/wire_simple.chdl)
```coffeescript
Wire (
  in: wire(8)
  out: wire(8)
)

build: ->
    assign(@out) => $ @in.reverse()
```
生成代码
```verilog
wire [7:0] in;
wire [7:0] out;
assign out = {in[0],in[1],in[2],in[3],in[4],in[5],in[6],in[7]};
```
示例代码(test/wire/wire_simple.chdl)
```coffeescript
assign(@out) => $ @in.select((i,bit)=> i%2==0)
```
生成代码
```verilog
assign dout = {w3[4],w3[2],w3[0]};
```
 
对wire类型的逻辑操作符完全兼容verilog语法
	
## 函数抽象
coffee-hdl支持函数抽象表达以增强代码复用,函数声明方式是普通
coffeescript函数,传入信号作为局部变量,在$表达式内使用的时候需要{}符号求值,函数的输出为$表达式,表现形式如下
	
示例代码(test/function/func_test.chdl)
```coffeescript
add: (v1,v2) -> $ @in3+{v1}+{v2}
mul: (v1,v2) -> $ {v1}*{v2}
build: ->
  assign(@out) => $ @add(@mul(hex(10,0x123),@in1),@in2)
```

生成代码

```verilog
assign out = in3+10'h123*in1+in2;
```

函数抽象可以无限嵌套调用.
	
## 寄存器,时钟,复位信号
coffee-hdl中的reg类型元素和verilog中d-flipflop存储类型对应,寄存器相关的有时钟
和复位信号可以来自于以下几处定义,后一种定义优先级更高.
1. 如果没有设置@disableAutoClock(),模块会自动生成_clock,_reset两个输入信号作为defaultclock,defaultreset
2. 继承自上级模块的defaultclock,defaultreset会覆盖当前的_clock,_reset
3. 当前模块指定的第一个clock和reset属性的input作为defaultclock,defaultreset
4. 申明reg时候指定的clock/reset信号,如果没有指定,选择defaultclock,defaultreset
clock相关示例代码请参见(test/clock/)

简单的声明形式如下
    
```coffeescript
Reg ff_simple: reg(16)
```
    
指定clock,reset信号的寄存器申明如下
	
```coffeescript
Reg ff_full: reg(16).clock('clock').init(0).asyncReset('rstn')
```

coffee-hdl中reg是一个大幅度增强语义的类型元素,在声明的时候可以指定相关时钟信号名字,复位信号名和复位值,还可以指定式异步复位还是同步复位,编译器会产生对应的verilog代码来表现这些特性,coffee-hdl编程的时候可以过滤这些特性获取reg列表.

reg可以和wire一样组织成数组类型,map类型或者复合类型数据结构.reg在生成verilog
代码的时候会产生一个伴生的d端信号,用"_"作前缀.比如上述就寄存器会自动产生如下代码
	
```verilog
reg [15:0] ff_full;
reg [15:0] _ff_full;
always @(posedge clock or nedgedge rstn) begin
	if(!rstn) begin
		ff_full <= 0;
	end
	else begin
		ff_full <= _ff_full;
	end
end 
```
		
此后所有对ff_full寄存器的赋值都体现在对_ff_full信号赋值的组合逻辑中.

	进一步加强的语义包括如下一些方法：
	
	* enable(signal,enable_value) reg使能信号,可以根据全局策略自动生成clock gating电路
	* clock(clock_name) 指定clock信号名
	* syncReset()  同步复位
	* noReset() 无复位
	* highReset() 复位信号高有效,缺省是低有效
 ~~maxcut(value) 赋值如果大于最大值截断到最大值~~

 ~~maxround(value)  赋值如果大于等于最大值,绕回到复位值~~

 ~~hold(signal,cycles) 当signal为高时,维持当前值cycles个周期~~

 ~~onecycle(signal) 当signal为高时,维持当前值1一个周期,然后回到复位值~~

 ~~decode(address,addrwire) 根据地址线解码选择~~

 ~~read(readenwire,readdataout) 配合decode读出数据~~

 ~~write(writeenwire,writedatain) 配合decode写入数据~~
	
	加强的语义会产生相应的verilog代码,或者在生成verilog代码的时候作相应的检查
		
## 状态机
针对状态机,reg类型有以下方法来管理状态
* stateDef(array|map)

  设置状态名称,示例代码(test/reg/reg_state.chdl)

```coffeescript
@ff1.stateDef(['idle','write','pending','read'])
```

  生成代码

```verilog
localparam ff1__idle = 0;
localparam ff1__write = 1;
localparam ff1__pending = 2;
localparam ff1__read = 3;
```

  也可以用map数据类型指定状态值,示例代码(test/reg/reg_state.chdl)
		
```coffeescript
@ff2.statedef({
	idle: 100
	send: 200
	pending: 300
	})
```
				
生成代码
```verilog
localparam ff2__idle=100;
localparam ff2__send=200;
localparam ff2__peding=300;	
```

* isState(state_name)

  判定寄存器值是某个状态,比如
		
```coffeescript
@ff1.isState('idle')
```
  生成如下代码
		
```verilog
ff1==ff1__idle
```
			
* notState(state_name)

  判定寄存器值不是某个状态,等价于isState取反

* setState(state_name)

  设置状态,比如
		
```coffeescript
@ff1.setState('write')
```
  生成如下代码
			
```verilog
_ff1 = ff1_write
```
	其中_ff是寄存器d端,ff_write是localparam
	
* stateSwitch

  状态转移逻辑如果足够简单的话可以使用reg内置stateSwitch方法设定

示例代码(test/reg/reg_state.chdl)
```coffeescript
always =>
  @ff1.stateSwitch(
    write:
      pending: => $ @stall==1
      idle: => $ @quit==1
    pending:
      read: => $ @readEnable==1
      idle: => $ @quit==1
      )
```
生成代码
```verilog
always_comb begin
  if(ff1==ff1__write && stall==1'b1) begin
    _ff1 = ff1__pending;
  end
  if(ff1==ff1__write && quit==1'b1) begin
    _ff1 = ff1__idle;
  end
  if(ff1==ff1__pending && readEnable==1'b1) begin
    _ff1 = ff1__read;
  end
  if(ff1==ff1__pending && quit==1'b1) begin
    _ff1 = ff1__idle;
  end
end
```
## 端口
在 coffee-hdl中,端口被定义为附加在wire上的一种属性,使得wire对模块外部拥有output/input方向属性,端口也可以组织成数组,map,或者复杂数据结构,还可以把端口数据结构单独存放在coffee模块当中,作为协议给hdl模块共享

示例代码(test/port/port_complex.chdl)

协议
```coffeescript
{input,output} = require 'chdl_base'

out_port={
  enable: output()
  dout: output(5)
}

in_port={
  enable: input()
  din: input(5)
}

module.exports.in_port = in_port
module.exports.out_port = out_port
```
使用
```coffeescript
#########################################################3
# Design
#########################################################3
{in_port,out_port} = require 'port_def'

class PortComplex extends Module
  constructor: ->
    super()
    
    Port(
      bus: [
        out_port
        in_port
      ]
    )

  build: ->
module.exports=PortComplex
```
生成代码
```verilog
module PortComplex(
  output bus__0__enable,
  output [4:0] bus__0__dout,
  input bus__1__enable,
  input [4:0] bus__1__din,
  input _clock,
  input _resetn
);
endmodule
```
端口进一步加强的语义包括如下一些方法：
* fromReg(reg_name:string): 当前output端口为reg_name的q端 (test/reg/reg_simple.chld)
			
除了标准的input/output以外,还可以用bind(channel_name)的方式来连接通道,其方向和宽度由通道对接的端口的属性来决定,具体含义见下一章.
	
## 通道(channel)

通道是对连接的抽象,在coffee-hdl中,channel的作用是取代verilog例化cell时候的port-pin连接的方式.和port-pin连接主要的区别channel是运行时确定宽度信息并检查,channel可以通过传统的port-pin方式逐步穿越层次,也可以跨层次互联自动生成端口.声明语句如下:
```coffeescript
@some_cell.bind(
  port_name: channel 'channel_name'
)
```
  或者
```coffeescript
Probe(
  channel_name: channel('cell.channel_name')
)
```  
前一种形式代表从cell pin绑定channel,
后一种形式代表从子层次模块抽取channel到当前模块

如果把channel作为端口引出当前模块
```coffeescript
Port(
  some_port: bind('channel_name')
)
```
把channel作为wire使用需要做显式转换,由于绑定的端口可能是数据结构,需要在参数当中指定数据结构成员

```coffeescript
assign(@dout) => $ @cell2_port.din+('cell1_ch','din')(3:0)+@cell2_probe.getWire('din')
```

生成代码
```verilog
assign dout = cell2_port__din+cell1_ch__din[3:0]+cell2_probe__din;
```

## 流水线
为更好的生成流水线类型的verilog代码,模块内嵌了一个pipe模式,如果不使用pipe模式,用户也可以用always手动的生成流水线.

示例代码(test/pipeline/pipe_test.chdl)
		
```coffeescript
pipeline('sync')  
.next((pipe)=>
	#level 1 pipe logic
	assign_pipe(d1:32) => $ @din 
).next((pipe)=>
	#level 2 pipe logic
	assign_pipe(d2:32) => $ {pipe.d1} 
).final((pipe)=>
	#some combo logic
	assign(@dout) => $ (!{pipe.d1}) & {pipe.d2}
)
```

在使用pipe模式的时候,需要指定流水线的名字,此处为'sync', 如果有需要可以在第二个参数设定pipeline相关属性,然后在.next参数中放入每级pipeline需要执行的电路,每级pipeline所需要暂存数据的寄存器通过assign_pipe自动生成,参数是(名字:位宽)形式的对象,默认情况下assign_pipe生成的寄存器不需要复位,需要复位的话可以通过第二个参数设定.

每一级next语句代表了pipeline的一拍,next参数是一个回调函数,函数的参数(示例中起名叫pipe)是生成的pipeline对象,引用流水线中的寄存器的时候,使用{ pipe.name }符号.当流水线结束的时候,使用.final函数,.final参数中放入的是组合逻辑,对输出信号赋值.通常可以把pipe电路封装成函数,把名字,输入信号,输出信号作为函数参数,可以极大提高代码的的复用.以上示例代码生成的verilog如下
		
```verilog
reg [31:0] sync___d1;
reg [31:0] sync___d2;
assign dout = (!sync___d1)&sync___d2;
always @(clock) begin
  sync___d1 = din;
end

always @(clock) begin
  sync___d2 = sync___d1;
end
```	
当前property_obj支持的属性
* hasReset: 值为reset信号名,如果值为null,使用模块缺省reset信号

## 分支
coffee-hdl 提供了能生成等价if else形式的verilog代码的能力,coffee-hdl的数字逻辑分支形式如下
```coffeescript
$if(cond) =>
  block_code1
$elseif(cond) =>
  block_code2
$else =>
  block_code3
$endif()
```
在assign环境下,分支语句块的返回值自动生成?:表达式,在always环境下,分支语句生成if elseif形式的组合逻辑.
示例代码(test/branch/branch_test.chdl)
```coffeescript
assign(@w2.w4) =>
  $if(@in1==hex(5,1)) =>
    $ @w2.w3+1
  $elseif(@in1==hex(5,2)) =>
    $ @w2.w3+2
  $endif()

assign(@w2.w4) =>
  $balance(@w2.w4.getWidth()) [
    $cond(@in1(1)) => $ @w2.w4
    $cond(@in1(2)) => $ @w2.w5
  ]

always =>
  $if(@in1==hex(5,1)) =>
    assign(@r1(3,1)) => $ @din(4,2)+0x100
  $elseif(@in1==hex(5,2)) =>
    assign(@r1(3,1)) => $ @din(4,2)+0x200
  $endif()
```
生成代码
```verilog
assign w2__w4 = (in1==5'h1)?w2__w3+1'b1:(in1==5'h2)?w2__w3+2'd2:0;
assign w2__w5 = ({32{in1[1]}}&(w2__w4))|({32{in1[2]}}&(w2__w5));
always_comb begin
   _r1=r1;
   if(in1==5'h1) begin
     _r1[3:1] = din[4:2]+9'h100;
   end
   else if(in1==5'h2) begin
     _r1[3:1] = din[4:2]+10'h200;
   end
 end
```
## 便利函数
@initial(list)
> 把list里面的字符串放入initial begin end中

@verilog(string)
> 字符串输出到生成代码,例如
	 
```coffeescript
@verilog('$display("data is %d",ff1);')
```

会在生成的verilog代码中插入 $display("data is %d",ff1);
示例代码(test/function/func_test.chdl)
	 
##  集成
除了使用通常的port-pin方式逐步向上信号互联集成的方式以外,coffee-hdl还可以使用Hub方式集成.

申明方式如下:
```coffeescript
Hub(
    connect_name: ['channel_name1','channel_name2',...]
    )
```
当前层会产生一套以connect_name名字开头的线,互联列表中的所有channel所关联的信号名字,根据名字和方向匹配,完成互联.互联完成以后如果有浮空的input会报错.

示例代码(test/integration/hub_simple.chdl)
```coffeescript
class HubSimple extends Module
  u0_cell1: new cell1()
  u0_cell2: new cell2()

  constructor: ->
    super()

    Hub(
      bus_channel: ['u0_cell1.master_channel','u0_cell2.slave_channel']
      )
  build: ->
```
 
## 关键字
操作符
* assign(signal) =>
* assign_pipe(reg_name:string,width:number)=>
* always =>
* pipeline(pipe_name,property) =>
* cat(signal1,signal2...)
* op_reduce(list,operator)
* get_channel(channel_name)

类型
* input(width:number)
* output(width:number)
* vec(width:number,depth:number)
* bind(name:string)
* reg(width:number)
* channel(name:string)
* wire(width:number)
* hex(width:number,value:number)
* oct(width:number,value:number)
* bin(width:number,value:number)
* dec(width:number,value:number)


电路生成
* $if(expr) =>
* $elseif(expr) =>
* $else =>
* $endif()
* $balance(number:number) =>
* $order(expr) =>
* $cond(expr) =>
* $default =>
* $expand
* $ expr

模块资源申明
* Port()
* Probe()
* Wire()
* Mem()
* Reg()
* Hub()

模块自带方法
* @setBlackBox()
* @specifyModuleName(name:string)
* @setCombModule()
* @verilogParameter(parameter_string:string)
* @verilog(verilog_string:string)
* @initial(list:string[])

## 感谢
powelljin,lizhousun两位对本项目提的意见以及小白鼠工作
