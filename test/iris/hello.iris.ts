const chdl_base = require('chdl_base')
const {_expr}=require('chdl_utils')
const {cat,expand,all1,all0,has0,has1,hasOdd1,hasEven1}=require('chdl_operator')
const {infer,hex,oct,bin,dec}= require('chdl_base')
const {_importLib}= require('chdl_transpiler_engine')
module.paths.push('/home/wood/work/gitlab/coffee-hdl/test/iris')
class hello extends chdl_base.Module {
  constructor() {
    super()

    this._port({
      din: chdl_base.input(32),
      enable: chdl_base.input(),
    })

    this._wire({
      a: this._localWire(),
      b: this._localWire(),
      c: this._localWire(),
    })

    this._reg({
    })

    this._channel({
    })
  }

  build() {
    this._initial (null,()=>{
      this._sequenceDef().init(()=>{
        /*
        while(a<10) {
          a= a+1
          while(a>5) {
            a= a+2
          }
        }
        if(din==1 && a>=100) {
          b= (100+(b<<12))
          if(a>=234) {
            c = a*b
          }
        } elseif(enable) {
          b= (300*2-100)
        } $else {
          b= (200)
        }
        b=a+c
        */
        this._while(chdl_base.Expr.start().next(this.a).next('<').next(10)) (()=>{
          this._assign(this.a) (()=>{
            return _expr(chdl_base.Expr.start().next(this.a).next('+').next(1))
          })
          this._while(chdl_base.Expr.start().next(this.a).next('>').next(5)) (()=>{
            this._assign(this.a) (()=>{
              return _expr(chdl_base.Expr.start().next(this.a).next('+').next(2))
            })
          ;this.annotate('yield;jump();');})
        ;this.annotate('yield;jump();');})
        this._if(chdl_base.Expr.start().next(this.din).next('==').next(1).next('&&').next(this.a).next('>').next('=').next(100)) (()=>{
          this._assign(this.b) (()=>{
            return _expr(chdl_base.Expr.start().next(100).next('+').next('(').next(this.b).next('<<').next(12).next(')'))
          })
          this._if(chdl_base.Expr.start().next(this.a).next('>').next('=').next(234)) (()=>{
            this._assign(this.c) (()=>{
              return _expr(chdl_base.Expr.start().next(this.a).next('*').next(this.b))
            })
          ;this.annotate('yield;');})._endif()
        ;this.annotate('yield;');}) ._elseif(chdl_base.Expr.start().next(this.enable)) (()=>{
          this._assign(this.b) (()=>{
            return _expr(chdl_base.Expr.start().next(300).next('*').next(2).next('-').next(100))
          })
        ;this.annotate('yield;');}) ._else() (()=>{
          this._assign(this.b) (()=>{
            return _expr(chdl_base.Expr.start().next(200))
          })
        ;this.annotate('yield;');})._endif()
        this._assign(this.b) (()=>{
          return _expr(chdl_base.Expr.start().next(this.a).next('+').next(this.c))
        })
      }).end()
    })
  }
}

module.exports=hello
