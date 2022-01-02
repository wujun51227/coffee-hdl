

# Coffee-HDL 用户手册 v0.7

##  介绍

本文档是Coffee-HDL(CoffeeScript hardware description language)的使用手册.Coffee-HDL是嵌入在
CoffeeScript编程语言中的硬件构造语言,是一种对CoffeeScript语言做了词法编译的改造扩充后的DSL,
所以当您编写Coffee-HDL时,实际上是在编写构造硬件电路的CoffeeScript程序.

作者并不假定您是否了解如何在CoffeeScript中编程,我们将通过给出的例子指出必要的Coffee-HDL语法特
性,大多数的硬件设计可以使用本文中包含的语法来完成.在1.0版本到来之前,还会有功能增加和语法修改，
所以不保证后继版本向下兼容.

对于宿主语言CoffeeScript 我们建议您花费几个小时浏览[coffeescript.org](https://coffeescript.org)
来学习CoffeeScript的基本语法,CoffeeScript是一门表达能力很强但是又非常简单的动态语言,最终编译器
会翻译成javascript语言通过nodejs引擎运行, 进一步的学习请参考一本优秀的CoffeeScript书籍 
["CoffeeScript in action"](https://www.manning.com/books/CoffeeScript-in-action).



##  安装
Coffee-HDL需要nodejs v10以上环境支持以及2.4以上版本的CoffeeScript编译器支持,如果操作系统没有自
带nodejs环境,请在 https://nodejs.org/en/download/ 下载相应版本,解压缩以后把path指向nodejs安装目
录的bin目录.

Coffee-HDL安装步骤

		git clone https://gitee.com/woodford/coffee-hdl.git
		cd coffee-hdl
		npm install
		source sourceme.sh
		./setup.sh

##  设计目标
Coffee-HDL关注二进制逻辑设计,能表达所有的verilog时序电路和组合电路,包括多时钟,同步异步复位,带延
迟的非阻塞赋值,时钟门控结构,请把Coffee-HDL当作语义化的rtl描述语言,而不是高级抽象描述语言.

Coffee-HDL的设计目标按优先级排列如下:

* 语义化表达电路结构

* 方便模块集成和互联

* 语义化指导综合等流程工具

* 对verilog互动友好,生成代码可读性良好,易于debug

* 强调参数化设计,动态生成verilog描述,彻底去除使用define条件编译

* 仿真器中立,对功能验证提供高层次的支持

  

除此以外，Coffee-HDL还注重以下几点

* 轻量化,容易部署，融入Javascript生态

* 编译快速

* 支持静态CDC检查

Coffee-HDL的未来要实现的功能	

* 使用宿主语言CoffeeScript仿真

## 编译

编译命令chdl_compiler.coffee使用方式

```
 chdl_comiler.coffee design.chdl --output directory
 ```

 编译完成以后会在design.chdl所在目录下生成design.chdl.js文件，生成相应的verilog代码在directory目录
 下面。编译流程如下图所示


 ```ascii-draw
=root                                                                                                        
0.2 .                                                                                                            
    .     .                   ["design.chdl"@s1#3]                               . ["lib.chdl"@s1#3]             
0.5 .     .                   .                             v .                  . .                        v    
    .     .                   ["chdl_compiler.coffee"@s2#3]                      . ["chdl_lib.coffee"@s2#3]      
0.5 .     .                   .                             v .                  . .                        v    
    .     .                   ["desigh.chdl.js"@s1#3]                            . ["lib.chdl.js"@s1#3]          
0.5 .     .                   .                             v .                  . .                        v    
    .     .                   ["nodejs"@s2#7]                                                                    
0.5 .     .                   .                             v .                  . .                        v    
    .     .                   ["verilog files"@s1#3]                             . ["report file"@s1#3]          
0.5 .     .                   v                             . v                                                  
    .     ["simulation"@s5#2]                               . ["synthesis"@s5#2]                                 
                                                                                                                 
0.2 .                                                                                                            
 ```

## 文件类型和模块
Coffee-HDL模块描述文件以.chdl作为文件后缀名,一个模块一个文件.导入模块
使用importDesign("design.chdl"),  其中design可以省略.chdl后缀名,
如果导入普通CoffeeScript模块,使用标准的require方式导入.

Coffee-HDL描述文件可以分为两类，模块设计文件和函数库文件:

1.	模块设计文件：每个文件包含一个硬件设计模块，对应verilog语言的Module，需要使在模块顶部

> module_name=importDesign(“design”)

   的方式导入以后才能使用。


2.	函数库文件：每个文件包含一些能生成硬件电路的函数，这些函数将会展开成数字逻辑电路，
在构造函数通过

> Mixin importLib(“lib”)

或者通过绑定对象

> @lib = MixinAs importLib("lib")

语句引入函数库。

函数库分为系统自带的库和第三方库，函数库在导入之前需要使用chdl_lib.coffee编译成相应的.js文件才能使用
。系统自带库只需要给出名字，
第三方库需要提供路径(绝对路径或者相对路径)。通过Mixin方式导入的函数可以当作类成员函数来使用，
如果绑定了对象，则当作对象的成员函数来使用，库函数约定凡是返回硬件电路的函数名都需要使用$前缀，
编程人员可以通过函数名清晰的知道该函数会生成电路。编译器缺省会导入自带的chdl_primitive_lib函数库，
该函数库提供了一些常用电路生成函数。

电路模块内容一般是三部分组成

1. 实例化子模块
2. 在构造函数内申明port,wire,channel,reg等资源,并且绑定channel到子模块的端口
3. 在build函数内描述模块的数字逻辑,主要是assign,consign等语句构成

示例代码(test/integration/import_simple.chdl),语法细节请参见后面的介绍

```coffeescript
cell1 = importDesign('./cell1.chdl')  #引入子模块

class ImportSimple extends Module     #申明当前模块
  constructor: ->
    super()
    
    CellMap(
       u0_cell1: new cell1()          #例化子模块
    )

    Port(                             #端口申明
      bindBundle: bind('up_signal')   #绑定通道
      clock: input().asClock()        #输入时钟信号
      rstn: input().asReset()         #输入复位信号
    )

    Reg(
      data_latch: reg(16)            #寄存器
    )

    Wire(
      data_wire: wire(16)           #线
    )
    
    Channel(
    	up_signal: channel()       #通道
    )

    @u0_cell1.bind(
      bundle:  @up_signal   #通道和例化模块端口对接
    )

  build: ->                         #模块内部数字逻辑
    assign @data_wire = @up_signal.din+1

    always
      consign @data_latch = @data_wire*2

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

## 模块属性

模块可以通过Property()方法设置属性，以下是模块相关的属性列表

```csv-text
属性名,类型,缺省值,描述
blackbox, boolean,false,"如果是true,当前模块是blackbox模块,不需要编译输出 verilog代码"
module_name, string,auto,"设置当前模块名字,缺省等同于类名"
comb_module,boolean,auto,"设置当前模块是纯组合逻辑模块,缺省根据 是否有clock输入判定是不是纯组合逻辑模块"
default_clock,string,auto,设置当前模块的主时钟
default_reset,string,auto,设置当前模块的主复位
uniq_name,boolean,true,"如果是false,设置所有实例化模块共享同样的模块名"
lint_width_check_overflow,boolean,true,"如果是true,检查 信号赋值溢出,被传递信号宽度必须大于等于激励表达式"
lint_width_check_mismatch,boolean,false,"如果是true,检查 信号赋值宽度必须一致,当设置为true的时候,lint_width_check_overflow无效"
lint_width_check_disable,boolean,false,"如果是true,不检查 信号宽度,当设置为true的时候,lint_width_check_mismatch ,int_width_check_overflow无效"
module_parameter,list,[]," 设置模块的verilog参数,格式为[{key:parameter_name,value:default_value}...]"
override_parameter,list,[]," 设置实例化模块时候覆盖verilog参数,格式为[{key:parameter_name,value:default_value}...]"

```

## 语言要素

1.	 标识符
     Coffee-HDL语言标识符可以是任意字母，数字，$符号和 _ 符号的组合，但是标识符的第一个字母
     不可以是数字或者 _ ,标识符中不可以出现 _ _ (连续两个下划线)。标识符的区分大小写的。
     以下标识符都是合法的：
     
* add
* ADD
* Add_1
* $add

    这些标识符是不合法的

*  _add
*  Add__1
*  1add


2. 注释
   Coffee-HDL使用CoffeeScript定义的#号作为行注释的起始符号，用###作为多行注释的起始和结尾符号

   

3. 格式
   Coffee-HDL的标识符区分大小写。Coffee-HDL语句块使用缩进代表作用域范围，
   具体规则请参见CoffeeScript语言手册。

   

4. 数值字面量

   Coffee-HDL数值字面量指保存在wire或者reg的bit值,在Coffee-HDL里面不支持X态和Z态,
   只有0和1两种状态,数值字面量一般带有宽度信息.,字面量类型沿用verilog的表达形式

   有三种表达形式:
```
	a. 使用函数hex/oct/bin/dec(width,value)生成verilog中的字面量表达,比如

		hex(32,0x55aa) => 32'h55aa
		bin(4,0x3)     => 4'b0011

    b. 使用[width]’[hodb][value]’字面量表达,比如

		32'h55aa' => 32'h55aa
		4'b0011'  => 4'b0011

	c. 使用CoffeeScript基本整数类型,如果宽度大于32,需要在数字最后加上n，表达为BigInt数据类型。
	   编译器会根据数据有效宽度自动加上宽度信息，比如
		
		0x55aa => 15'h55aa
		0xffffffffffn => 40'hffffffffff
```

示例代码如下

```verilog
		hex(12,0x123) // 12'h123
		hex(0x123)    // 'h123
		hex(123)      // 'h7b
		bin(9,12)     // 9'b1100
		oct(12, 123)  // 7'o173
		0x123         // 'h123
		0b1100        // 'b1100
		12'h123'      // 12'h123
		32'hffff55aa' //32'hffff55aa
```



## 组合电路表达

Coffee-HDL采用“$”符号作为verilog组合电路表达式的前导符,如果电路表达式是单行跟在assign
(signal) = 或者 consign(signal) = 后面可以省略$符号，电路表达式会产生相应的的v
erilog组合电路表达式,其中有几点需要注意

* 可以用 @variable_name 的方式直接引用模块内部使用Wire,Reg等资源
* 需有求值的部分必须放在{}中,比如局部变量,原生数据计算等等
* 除此以外的符号都按照字面量生成在verilog表达式当中
* 三目运算符的: 通过$if $else 结构代替
* 由于{}符号作为求值运算符存在,verilog原生的{}运算符的使用cat()函数代替
* 位扩展操作{n{net}}使用expand函数代替 

示例代码
```coffeescript
build: ->
  data=100
  assign(@out) = {data+1} + hex(5,0x1f)
```
生成代码
```verilog
assign out = 101+5'h1f;
```
## assign/consign
Coffee-HDL的组合电路通过assign/consign语句生成,被赋值对象可以是reg或者wire，

如果被赋值对象是reg类型变量，赋值动作生成连接到D Flip-flop输入端的组合电路，
reg会等到相应的时钟边沿更新到寄存器输出端。

赋值的右手边可以是等号后面的单行$表达式，也可以是缩进语句块的返回值，返回值必须是$表达式

Coffee-HDL的组合电路信号传递通过assign/consign语句生成,两者的区别在于assign是对wire传递
信号，consign是对reg的D端传递信号，如果用assign对reg传递信号，功能正确但是编译会提出警告，
consign对wire传递信号，编译会报错，表达方式为

```coffeescript
assign signal  = expression 
consign dff = expression
```
或者 
```coffeescript
assign signal
   语句块
   return $ result
consign dff
   语句块
   return $ result
```
语句块的返回值必须是$表达式产生的verilog语句

示例代码

```coffeescript
assign @dout
  $if(@sel1)    =>     $ @din+1
  $elseif(@sel2)  =>   $ @din+2
  $elseif(@sel3)  =>   $ @din+3
  $else          =>    $ @din
```

生成代码

```verilog
dout = (sel1)?din+1:(sel2)?din+2:(sel3)?din+3:din;
```

区分assign/consign的主要原因是在代码上可以直观的知道当前获得值的信号是组合逻辑还是寄存器，
被assign的信号，获得值当前可以继续运算，被consign的的信号，传递生效时间是下一个相关寄存器时钟
有效沿发生的时候，寄存器当前的值没有立即改变，如果需要获得寄存器D端的当前值可以使用寄存器成员
函数.next()获得，示例代码:

```coffeescript
consign dout1 = a + b
consign dout2 = dout1.next()
```

生成代码

```verilog
assign _dout1 = a + b;
always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        dout1 <= #`UDLY 0;
    end
   	else begin
        dout1 <= _dout1
    end
end
assign _dout2 = _dout1;
always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        dout2 <= #`UDLY 0;
    end
   	else begin
        dout2 <= _dout2
    end
end
```



这里dout2传递的是dout1的D端，所以dout1和dout2的值始终是一样的



## always

always后面跟随一个语句块，语句块由$if-$elseif-$else分支语句和assign/consign赋值语句组成，在always语句
块内assign/consign的对象可以是wire，也可以是reg。

```coffeescript
	always
	  语句块
```

如果assign对象是wire类型，编译器会通过给被赋值wire加上pending值（缺省是0）确保不会生成意外的latch，如果
assign对象是reg类型，编译器会自动把reg的输出端当成被赋值对象的pending值。wire和reg的pending的值可以显式的指定。

示例代码:

```coffee
always
	dout.pending(1)
	$if(enable)
		assign dout = din
```

生成verilog:

```verilog
always_comb begin
 	dout=1;  // dout 缺省状态为1
 	if(enable) begin
		dout = din;
	end
end
```

语法糖 always_if(cond) 是对

```coffeescript
	always
		$if(cond)
			语句块
```
的简化写法

示例代码
```coffeescript
dout = reg(8)
always
	$if(sel1)
		assign dout = 1
	$elseif(sel2)
		assign dout = 2
```
生成代码
```verilog
reg [7:0] dout;
wire [7:0] _dout;
always @(negedge clock or negedge resetn) begin
  if(!_reset) begin
    dout <= #`UDLY 0;
  end
  else begin
    dout <= #`UDLY _dout;
  end
end

always_comb begin 
  _dout = dout;
  if(sel1) begin 
  	_dout = 'd1;
  end
  else if(sel2) begin
  	_dout = 'd2;
  end
end
```

## wire 
wire类型是用于表达组合电路输出结果的元素,对应生成verilog的wire,最简单声明方式如下
```coffeescript
Wire wire_name: wire(number|[])
```

如果把wire组织成数组,声明方式如下

生成10个16bit宽度线

```coffeescript
Wire( 
    wire_array: wire(16) for i in [0..9]
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
  aaa: {
    bbb: wire(16)
    }
}
```

map数据结构可以通过@wire_struct.aaa.bbb的方式引用.

wire类型通过()操作符获取bit或者切片,data(1)取bit1,data(2:0)或者data(0,3)取bit[3:0],对于slice或者bit
可以设置字段名(setField)使其语义化,

示例代码
```coffeescript
constructor: ->
  Wire(
    result: wire(33).setField(
      carry: 32
      sum: [31:0]
      )
    )
    
build:->
  assign @result.field('carry') = 1
  assign @result.field('sum') = 32'h12345678'
```
生成代码
```verilog
assign result[32] = 1'b1;
assign result[31:0] = 32'h12345678;
```
如果参数是一个列表的话，列表里面是带有宽度信息的信号或者常量，生成的wire宽度是列表内宽度的总和，
这个wire会被assign成所有列表信号的拼接.

示例代码

```coffeescript
result = wire([a,b,10'b0'],'result') #a是10位，b是12位
```

生成代码

```verilog
wire [31:0] result_1;
assign result_1 = {a,b,10'b0};
```

还有一种wire,通过unpack_wire函数可以构造一种线，这种线可以解开成列表里面的信号，并自动计算宽度

示例代码

```coffeescript
data = unpack_wire([e,f],'data') # f是16位，e是8位
```

生成代码

```verilog
wire [23:0] __data_29;
assign __f_28 = __data_29[15:0];
assign __e_27 = __data_29[23:16];
```



wire类型带有以下常用方法

 * reverse() 产生同等宽度高低位逆序排列的线

 * select( (index)=> func) 根据函数式取得wire相应bit组成新的wire

 * toList() 把多比特wire按bit次序，变成一个list,例如3bit信号a, a.toList() 生成 [a(0),a(1),a(2)]

 * drive(list...)  当前寄存器驱动list里面的所有信号

 * setSign() wire为有符号数

 * ext(n): 虚拟扩展n位，避免lint时候高位溢出报警
    

    示例代码

```coffeescript
Wire (
  in: wire(8)
  out: wire(8)
)

build: ->
    assign @out = @in.reverse()
```
生成代码
```verilog
wire [7:0] in;
wire [7:0] out;
assign out = {in[0],in[1],in[2],in[3],in[4],in[5],in[6],in[7]};
```
示例代码
```coffeescript
assign @out = @in.select((i,bit)=> i%2==0)
```
生成代码
```verilog
assign dout = {w3[4],w3[2],w3[0]};
```



**wire的另外一种申明**

wire声明还有前缀表达形式Net signal/ Net(signal,width)/ SignNet(signal,width), 
以在后面直接加等号或者语句块赋值

> Net foo = bar 

相当于
> foo = wire()
>
> assign foo = bar

的缩略形式

## port
在 Coffee-HDL中,端口被定义为附加在wire上的一种属性,使得wire对模块外部拥有output/input方向属性,
端口也可以组织成数组,对象,或者复杂数据结构,还可以把端口数据结构单独存放在coffee模块当中,作为
协议给chdl模块共享

示例代码

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
#########################################################
# Design
#########################################################
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
  input clock,
  input resetn
);
endmodule
```
端口进一步加强的语义包括如下一些方法：
* asReg(): 当前output端口为reg的Q端,port拥有reg的所有能力

* asClock(): 当前input端口为时钟，如果是第一个时钟，则这个时钟是模块的缺省时钟

* asReset(): 当前input端口为复位信号，如果是第一个复位信号，则这个时钟是模块的缺省复位

* asGenerateClock(): 当前output端口为输出时钟


除了标准的input/output以外,还可以用bind("channel")的方式来连接通道,其方向和宽度
由通道对接的端口的属性来决定,具体含义见“通道”相关章节.


## reg,clock,reset
Coffee-HDL中的reg类型元素和verilog中D-flipflop存储类型对应,寄存器相关的有时钟
和复位信号可以来自于以下几处定义,靠前的定义优先级更高.

1. 含有寄存器的模块必须有时钟端口的输入，第一个申明的时钟输入信号是defaultClock,第一个声明的
复位输入信号是defaultReset
1. 如果声明reg时候指定clock/reset信号,使用指定的时钟和复位信号
1. 如果声明reg时候没有指定clock/reset信号,选择defaultClock,defaultReset

clock相关示例代码请参见(test/basic/reg_simple.chdl)

简单的声明形式如下
    
```coffeescript
Reg ff_simple: reg(16)
```

指定clock,reset信号的寄存器申明如下
	
```coffeescript
Reg ff_full: reg(16).clock('clock').init(0).reset('rstn')
```

Coffee-HDL中reg是一个大幅度增强语义的类型元素,在声明的时候可以指定相关时钟信号名字,
复位信号名和复位值,还可以指定式异步复位还是同步复位,编译器会产生对应的verilog代码来
表现这些特性,Coffee-HDL编程的时候可以过滤这些特性获取reg列表.

reg可以组织成数组,对象类型或者复合类型数据结构.在生成verilog
代码的时候会产生一个伴生的D端信号,用"_"作前缀.比如上述就寄存器会自动产生如下代码
	
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
	
* clock(clock_name) 指定clock信号名

* negedge() 时钟下降沿有效

* reset(signal) 指定reset信号名,如果signal是null,则这个寄存器没有reset

* syncReset()  同步复位

* highReset() 复位信号高有效,缺省是低有效

* init(value) 复位时寄存器值

* clear(signal，value) 当signal==value的时候，寄存器恢复成复位值

* stall(signal, value) 当signal==value的时候，寄存器值保持不变，优先级低于clear

* enable(signal,value) 当signal==value的时候，寄存器值可以改变，否则保持不变，优先级低于stall

* reverse() 生成同等宽度高低位逆序排列的wire

* select(function) 根据函数式取得相应bit组成新的wire

* toList() 把多比特寄存器按bit次序，变成一个list,例如3bit寄存器a,a.toList() 生成 [a(0),a(1),a(2)]

* drive(list...)  当前寄存器驱动list里面的所有信号

* setSign() 寄存器为有符号类型


**reg的另外一种申明**

reg声明还有前缀表达形式Dff signal/ Dff(signal,width)/ SignDff(signal,width), 可以
在后面直接加等号或者语句块赋值



##  操作符

除了连接，复制，规约操作符，其余操作符功能上和优先级与verilog操作符等价:

* 算术操作符 +(加) –(减) *(乘) /(除) %(取模)
* 关系操作符 >(大于)  <(小于) >=(大于等于) <=(小于等于)
* 相等关系操作符 ==(逻辑等) !=(逻辑不等)
* 逻辑操作符  &&(逻辑与) ||(逻辑或) !(逻辑取反)
* 位操作符 &(位与) |(位或) ~(位取反) ^(位异或) 
* 移位操作符 >>(左移) <<（右移）

Coffee-HDL连接，复制，规约操作符通过函数实现

* 连接

  cat(signal1, signal2,…) 等价于 {signal,signal2,…}

* 复制

  expand(n, signal) 等价于 {n{signal}}

* 归约操作符

```csv-text
    Name  ,  Description
  	all1(), 等价于 &
    all0(), 等价于 ~|
   	has0(), 等价于 ~&
   	has1(), 等价于 |
	hasOdd1(), 等价于 ^
	hasEven1(), 等价于 ~^
```

## 位选择和部分选择

- 位选择使用括号操作符signal(n)，选择signal第n位
- 部分选择使用两种形式

  - 高位到低位选择模式，signal(msb:lsb)，选择signal的第lsb位到msb位
  - 低位和宽度选择模式，signal(lsb,width)，选择从signal的第lsb位，选择宽度为width.
- 还有一些便利的的部分选择函数
  - fromMsb(n:number): 从高位选择n位信号，如果n是负数，则选择选择从高位开始的总宽度减去abs(n)的宽度
  - fromLsb(n:number): 从低位选择n位信号，如果n是负数，则选择选择从低位开始的总宽度减去abs(n)的宽度

## 分支
在verilog语言中，mux电路可以通过两种写法生成，一种是?:表达式，一种if-else语句块，
在Coffee-HDL语言中，这两种方式都被统一到$if-$elseif-$else语句，编译器自动根据上下文生成相应的 ? :操作符，
或者if else语句。

Coffee-HDL的数字逻辑分支形式如下

```coffeescript
$if(cond)
  block1
$elseif(cond)
  block2
$else
  block3
```
在assign环境下,分支语句块的返回值自动生成?:表达式,在always环境下,分支语句生成if elseif形式的组合逻辑.
示例代码
```coffeescript
assign(@w2.w4)
  $if(@in1==hex(5,1))
    $ @w2.w3+1
  $elseif(@in1==hex(5,2))
    $ @w2.w3+2

always
  $if(@in1==hex(5,1))
    assign(@r1(3,1)) = $ @din(4,2)+0x100
  $elseif(@in1==hex(5,2))
    assign(@r1(3,1)) = $ @din(4,2)+0x200
```
生成代码
```verilog
assign w2__w4 = (in1==5'h1)?w2__w3+1'b1:(in1==5'h2)?w2__w3+2'd2:0;
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




无优先级并行电路可以使用$balance语句,前提是程序员需要保证cond1,cond2互斥

示例代码

```coffeescript
assign(@out)
   $balance([                                      
    $cond(@cond1) => $ @data1                                           
    $cond(@cond2) => $ @data2                                           
  ] , 16)
```
生成代码
```verilog
assign out = (16{cond1}&(data1))|
            (16{cond2}&(data2));
```

如果需要批量化产生if elseif else语句,可以使用$order/$case语句

$order 示例代码
```coffeescript
assign @w2.w6
  $order([
    $cond(@in1(1)) => $ @w2.w3(9:7)
    $cond(@in1(2)) => $ @w2.w3(3:1)
	$cond(@in1(3))
    $cond(@in1(4)) => $ 100
    $cond() => $ @w2.w3(6:4)
    ]
  )
```

生成代码
```verilog
assign w2__w6 =(in1[1])?(w2__w3[9:7]):(in1[2])?(w2__w3[3:1]):(((in1[3])||(in1[4])))?(100):w2__w3[6:4];
```
$case 示例代码

```coffeescript
  always
      $case(@casein) =>
        [
          $lazy_cond(10) =>
            assign(@caseout) = 100
          $lazy_cond(20)
          $lazy_cond(30)
          $lazy_cond(40) =>
            assign(@caseout) = 200
          $lazy_cond() =>
            assign(@caseout) = 300
        ]
```

生成代码
```verilog
always_comb begin /* 121 */ 
  caseout=0;
  caseout /* 131 */ = 'd300;
  if((casein=='d20)||(casein=='d30)||(casein=='d40)) begin
  	caseout /* 129 */ = 'd200;
  end
  if(casein=='d10) begin
      caseout /* 125 */ = 'd100;
  end
end
```


## 函数抽象

Coffee-HDL支持用函数生成电路以增强代码复用,生成电路函数返回值必须为$表达式，
在函数内部可以声明局部wire和reg,编译器会确保在函数内部的wire和reg的变量名全局唯一，
函数可以嵌套调用。

Coffee-HDL支持函数抽象表达以增强代码复用,函数声明方式是普通
CoffeeScript函数,在$表达式内需要求值的时候使需要{}符号对包含在内部的表达式求值,
函数的输出为$表达式,表现形式如下
	
示例代码

```coffeescript
add: (v1,v2) -> $ @in3+v1+v2
mul: (v1,v2) -> $ v1*v2
build: ->
  assign @out = @add(@mul(10'h123',@in1),@in2)
```

生成代码

```verilog
assign out = in3+10'h123*in1+in2;
```

函数抽象可以嵌套调用.

## 状态机
针对状态机,reg类型有以下方法来管理状态

* stateDef(array|map)

  设置状态名称,示例代码(test/basic/reg_simple.chdl)

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

  也可以用对象数据类型指定状态值,示例代码(test/basic/reg_simple.chdl)
		
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

* isState("state"...)

  判定寄存器值是某个状态或者若干个状态之一,比如
		
```coffeescript
@ff1.isState('idle','write')
```
  生成如下代码
		
```verilog
ff1==ff1__idle||ff1__write
```

* notState("state")

  判定寄存器值不是某个状态,等价于isState取反

* setState("state")

  设置状态,比如
		
```coffeescript
@ff1.setState('write')
```
  生成如下代码	
```verilog
_ff1 = ff1_write
```
其中  _ ff 是寄存器D端,ff_write是localparam

* $stateSwitch

  状态转移逻辑可以使用$stateSwitch方法设定

示例代码(test/basic/reg_simple.chdl)
```coffeescript
  $stateSwitch(@ff1) =>
    'write': [
      $cond(@stall==1) => $ @ff1.getState('pending')
      $cond(@stall==0) => $ @ff1.getState('idle')
    ]
    'pending': [
      $cond(@readEnable==1) => $ @ff1.getState('read')
      $cond() => $ @ff1.getState('idle')
      ]
  )
```
生成代码
```verilog
always_comb begin
  _ff1 = ff1;
  if(ff1==ff1__write) begin
    if(stall==1) begin
      _ff1 = ff1__pending;
    end
    else if(stall==0) begin
      _ff1 = ff1__idle;
    end
  end
  if(ff1==ff1__pending) begin
    if(readEnable==1) begin
      _ff1 = ff1__read;
    end
    else begin
      _ff1 = ff1__idle;
    end
  end
end
```

## 实例化模块
在构造函数中使用CellMap或者CellList两种方式实例化子模块，实例化的子模块是无法
直接组织成数据来使用的。

CellMap有两种模式,一种是对象模式
```coffeescript
constructor: ->
    CellMap(
    	cell_name: new cell()
	)
```
或者是列表模式
```coffeescript
constructor: ->
    CellMap([
    	{name:'cell_name', inst: new cell()}
	])
```
在CellMap实例化的子模块名字都是程序员编程决定，这些名字都会作为当前模块的成员
变量存在，后面需要使用的时候通过@符号引用，比如@cell_name

如果不关心子模块的实例化名字，可以使用CellList来实例化这些子模块，编译器会自动
生成这些子模块的实例化名字，模块的引用需要程序员自己赋值给成员变量来使用
:w2
```coffeescript
constructor: ->
	list = (new cell() for i in [0...12])
    CellList(list...)
```
这里会实例化12个cell,实例化名字自动生成，对这些子模块的引用通过list[index]获得

## 通道

通道是对连接的抽象,在Coffee-HDL中,channel的作用是取代verilog例化cell时候的port-pin连接
的方式.和port-pin连接主要的区别channel是运行时确定宽度信息并检查,channel可以通过传统的
port-pin方式逐步穿越层次,也可以跨层次互联自动生成端口.声明语句如下:
```coffeescript
constructor: ->
    CellMap(
    	u0_cell: new sub_module()
	)
	Channel(
		din_ch: channel()
	)

	@u0_cell.bind(
  		din :   @ch
	)
```

这里的din_ch对应u0_cell.din



也可以使用mold函数，而不是显式bind

```coffeescript
constructor: ->
    CellMap(
    	u0_cell: new sub_module()
	)
	Channel(
		u0_cell_ch: mold(@u0_cell)
	)
```

这里的u0_cell_ch相当于是u0_cell，后面通过u0_cell_ch.din 来获得u0_cell.din



也可以使用Probe方式

```coffeescript
Probe(
  probe_ch: 'u0_cell.din_ch'
)
```
前两种形式代表从cell pin绑定channel,
Probe形式代表从子层次模块抽取channel到当前模块



如果把channel作为端口引出当前模块

```coffeescript
Port(
  din: bind('din_ch')
)
```
把channel作为wire使用时候，直接存取channel成员下的路径

```coffeescript
assign @dout = $ @cell1_ch.din(3:0)+@cell2_probe.din
```

生成代码
```verilog
assign dout = cell1_ch__din[3:0]+cell2_probe__din;
```

## CDC检查

Coffee-HDL语言按有时序逻辑的模块分别作CDC检查，凡是带有时钟的模块，所有的输入，输出信号
都有同步关系(缺省和defaultClock同步)，如果是纯组合逻辑模块，输入输出同步关系不做假设。
输入时钟有两种来源，一种
是来自于设计顶层的带asClock()声明的输入信号，一种是内部模块带asGenerateClock()声明的输出
信号，Coffee-HDL在编译期间，会追踪所有到输出端口的信号和到寄存器D端的信号，判定是否有跨
时钟域的信号抓取行为。

所有的信号的时钟域属性分为6类
```csv-text
 属性, 作为接受端, 作为发送端, 应用场景
 sync, 检查是否和当前信号相关时钟同步,要求接受端用同样时钟抓取, 寄存器到寄存器检查
 capture, 检查是否和当前信号相关时钟同步,发送稳态信号，任何接受端都可以抓取，并同步到接受端时钟, 无时序要求的状态设定寄存器
 unstable,检查是否和当前信号相关时钟同步,发送异步信号，要求接受端声明忽略时钟同步关系, 强制发送异步信号
 stable, 不检查同步关系,送稳态信号，任何接受端都可以抓取，并同步到接受端时钟, 传递稳态信号
 trans, 不检查同步关系,要求接受端用同样时钟抓取, 跨时钟域同步第一级寄存器
 async, 不检查同步关系,发送异步信号，要求接受端声明忽略时钟同步关系,传递异步信号
```
对于port的时钟域声明(缺省同步到模块缺省时钟)
```csv-text
,
sync(clock), 设置sync属性 同步到clock
async(),设置async属性
stable(),设置stable属性
capture(),设置capture属性
asyncLatch(),设置trans属性
asGenerateClock(), 设置当前信号为分频时钟 仅对输出信号有效
```

对于reg时钟域声明(缺省为同步到寄存器相关时钟)
```csv-text
,
stable(),设置stable属性
capture(),设置capture属性
asyncLatch(),设置trans属性
```
对于wire的时钟域声明(一般无需声明)
```csv-text
,
sync(clock), 设置sync属性 同步到clock
async(),设置async属性
stable(),设置stable属性
```

CDC静态检查使用：
```
chdl_compiler.coffee design.chdl --cdc --cdc_report file --output directory
```

编译完成以后会把CDC检查结果输出到指定目录的指定文件当中，如果不指定cdc_report则打印到屏幕。

CDC静态检查会报告当前设计所有时钟关系，顶层输入的所有时钟被认为是异步关系，按顶层的输入
时钟分成多个时钟域，例如
```
║ hclks │ ahb_to_ahb_async.hclks            ║
║       │ ahb_to_ahb_async.slave_side.hclk  ║
║       │ ahb_to_ahb_async.slave_ch__hclk   ║
║ hclkm │ ahb_to_ahb_async.hclkm            ║
║       │ ahb_to_ahb_async.master_side.hclk ║
║       │ ahb_to_ahb_async.master_ch__hclk  ║
```

报告结果如下图所示
```
║ Type   │ clock crossing                                             ║
║ Target │ ahb_to_ahb_async.hactivem(hclks)                           ║
║ Source │ ahb_to_ahb_async.master_ch__m_hactive(hclkm)               ║
```

表格里面会打印错误类型，源信号和时钟，以及目标信号和时钟。

当前CDC检查可以发现以下情况的错误

* 信号跨时钟域

```ascii-draw
=block1
   .... ""@s4#8
   .... "Dff"@s4#8
   clk1#2 =>#2  ""@s4#8

=block2
   .... ""@s4#8
   .... "Dff"@s4#8
   clk2#2 =>#2  ""@s4#8

=block3
   .... ""@s4#8
   -+3 "Dff"@s4#8
   clk1#2 =>#2  ""@s4#8

=root
0.2 
2    . *block1#2  - ""@s5#2  - *block3#2
0.5   .... "logic"@s5 #2 
2    .*block2#2  - ""@s5#2
0.2 
```
<br>

* 采样到异步信号

```ascii-draw
=block1
   .
   .... "Async Signal"#8
   .... =>@s4#8
   .
   .... "Sync Signal"#8
   .... =>@s4#8
   .
   .

=block2
   .... ""@s4#8
   -+3"Dff"@s4#8
   clk#2 =>#2  ""@s4#8

=root
0.2 
2    *block1#2   ["logic"@s5#2] -*block2#2
0.2 
```
<br>


* 生成时钟的跨时钟域

```ascii-draw
=clkgen
    .
    .
    .
   .....  ""@s4#7
   .....  "clkgen"@s4#7
   clk1#3 =>#2  ""@s4#7

=block1
   .... ""@s4#8
   .... "Dff"@s4#8
    =>#4  ""@s4#8

=block3
   .... ""@s4#8
   -+3 "Dff"@s4#8
   clk2#2 =>#2  ""@s4#8

=root
0.2 
2    . *clkgen#2 *block1#2  - "logic"@s5#2  - *block3#2
0.5  . ..... ""@s5 #2 
0.2 
```

<br>

* 被同步的异步信号汇聚

```ascii-draw
=block1
   "Async signal"#4 ""@s4#8
   =>#4 "Dff"@s4#8
   .... ""@s4#8
   clk1#2 =>#2  ""@s4#8

=block3
   .... ""@s4#8
   -+3 "Dff"@s4#8
   clk1#2 =>#2  ""@s4#8

=root
0.2  . 
2    .  *block1#2  - "logic"@s5#2  - *block3#2
0.5  .   ... ""@s5 #2 
2    .  *block1#2  - ""@s5#2
0.2  . 
```

## flow
可以在initial/forever中可以用$flow模式编程产生verilog行为语句
，操作对象一般是vreg类型变量，

可用的行为序列语句
* posedge(signal:string|object,delay)
* negedge(signal:string|object,delay)
* wait(expression:$expr)
* go(delay:number)
* trigger(trigger_name:string) 
* event(tringger_name:string)
* polling(signal:string|object,expr:$expr) 

示例代码
		
```coffeescript
initial
  $flow =>
    assign @cs = 0
    posedge(@sel)
    assign @cs = 1
    assign @addr_out = @addr
    go(5)
    negedge(@sel)
    assign @cs = 0
    assign @addr_out = 16'hffff'
    wait($(@finish==1))
    assign @addr = @addr+4
```

## 序列
为了把更加容易理解的序列操作变成硬件电路，可以用$sequence模式编程，
序列必须在always中出现,并且可综合成硬件电路，操作对象是reg,port,wire.

可综合序列触发条件和回调函数形式

* posedge(signal:string|object) (trans,next) =>
* negedge(signal:string|object) (trans,next) =>
* next(cycle: number) (trans,next)=>
* wait(expression:$expr) (trans,next)=>
* end()

可综合事件对应的回调函数带有两个参数，第一个参数trans是进入状态的的信号,第二个参数next
是退出状态时候的信号

示例代码
		
```coffeescript
always
  $sequence('writeSeq') =>
     assign @cs = 0
    .posedge(@sel) =>
      assign @cs = 1
      assign @addr_out = @addr
    .next(5) =>
    .negedge(@sel) (trans,next)=>
      $if(trans)
        assign @cs = 0
      $elseif(next)
        assign @addr_out = 16'hffff'
    .wait($(@finish==1)) =>
      assign @addr = @addr+4
    .end()
```

在always当中如果使用序列，编译器会在最终状态自动根据第一个状态的触发条件决定是回到idle,还是
直接进入第一个状态.

##  集成
除了使用通常的port-pin方式逐步向上信号互联集成的方式以外,Coffee-HDL还可以使用hub方式集成.

申明方式如下:
```coffeescript
$channelPortHub(channel1,channel2,...)
```
当前层会产生一套互联列表中的所有channel所关联的信号名字,根据名字和方向匹配,完成互联.
互联完成以后如果有浮空的input会报错.

示例代码
```coffeescript
class HubSimple extends Module
  
  constructor: ->
    super()
    
    CellMap(
        u0_cell1: new cell1()
  		u0_cell2: new cell2()
    )

    Probe(
      aaa: 'u0_cell1.master_channel'
      bbb: 'u0_cell2.slave_channel'
    )

  build: ->
    $channelPortHub(@aaa,@bbb)
```

通过channel的连接方式,模块的层次结构很容易重构,如下面的例子所示

Diagram 1

```mermaid
  graph LR
    aaa-- channel 1---bbb
    aaa-- channel 2---ccc
    subgraph domain1
    aaa
    end
    subgraph domain2
    bbb
    ccc
    end
```

```coffeescript
class top extends Module
 
  constructor: ->
    super()
    
    CellMap(
     	domain1: new cell1()
  		domain2: new cell2()
	)

    Probe(
      aaa1: 'domain1.ch1'
      aaa2: 'domain1.ch2'
      bbb: 'domain2.ch'
      ccc: 'domain2.ch'
    )

  build: ->
    $channelPortHub(@aaa1,@bbb)
    $channelPortHub(@aaa2,@ccc)
```

---
Diagram 2
```mermaid
  graph LR
    aaa-- channel 1---bbb
    aaa-- channel 2---ccc
    subgraph domain1
    aaa
    end
    subgraph domain2
    ccc
    end
    subgraph domain3
    bbb
    end
```

```coffeescript
class top extends Module

  constructor: ->
    super()
    
    CellMap(
    	domain1: new cell1()
  		domain2: new cell2()
  		domain3: new cell3()
	)

    Probe(
      aaa1: 'domain1.ch1'
      aaa2: 'domain1.ch2'
      ccc: 'domain2.ch'
      bbb: 'domain3.ch'
    )

  build: ->
    $channelPortHub(@aaa1,@bbb)
    $channelPortHub(@aaa2,@ccc)
```



## 关键字

操作符

* assign signal [= expr || block]
* consign signal [= expr || block]
* always block
* always_if(cond) block

类型

* input(width)
* output(width)
* vec(width,depth)
* bind(name)
* reg(width)
* channel()
* wire(width)

电路生成

* $if(expr)
* $elseif(expr)
* $else
* $cond(expr) =>
* $ expr
* $expand(times,signal)
* $cat(signal1,signal2...)
* $order(list)
* $balance(list)

模块资源申明

* Port()
* Probe()
* Wire()
* Net()
* Dff()
* Channel()
* Mem()
* Reg()

全局方法

* verilog(verilog_string) 用在always,initial中
* verilog_segment(multi_line_string) 用在顶层
* display(print_string,args...) 
* mold(instance)
* assignee_width() 被赋值信号宽度
* get_parameter(key_string) 获取verilog parameter的参数值

## 破坏性更新

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
  @targetWidth()       , assignee_width()
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




## 感谢
powelljin,lizhousun,siyu,solar对本项目提的意见
