// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header

#ifndef _VAssignCond__Syms_H_
#define _VAssignCond__Syms_H_

#include "verilated.h"

// INCLUDE MODULE CLASSES
#include "VAssignCond.h"

// SYMS CLASS
class VAssignCond__Syms : public VerilatedSyms {
  public:
    
    // LOCAL STATE
    const char* __Vm_namep;
    bool __Vm_didInit;
    
    // SUBCELL STATE
    VAssignCond*                   TOPp;
    
    // CREATORS
    VAssignCond__Syms(VAssignCond* topp, const char* namep);
    ~VAssignCond__Syms() {};
    
    // METHODS
    inline const char* name() { return __Vm_namep; }
    
} VL_ATTR_ALIGNED(64);

#endif // guard
