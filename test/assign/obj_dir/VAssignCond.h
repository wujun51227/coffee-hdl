// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Primary design header
//
// This header should be included by all source files instantiating the design.
// The class here is then constructed to instantiate the design.
// See the Verilator manual for examples.

#ifndef _VAssignCond_H_
#define _VAssignCond_H_

#include "verilated.h"

class VAssignCond__Syms;

//----------

VL_MODULE(VAssignCond) {
  public:
    
    // PORTS
    // The application code writes and reads these signals to
    // propagate new values into/out from the Verilated model.
    VL_IN8(_clock,0,0);
    VL_IN8(_resetn,0,0);
    VL_IN64(add1,59,0);
    VL_IN64(add2,59,0);
    VL_OUT64(dout_q,60,0);
    
    // LOCAL SIGNALS
    // Internals; generally not touched by application code
    VL_SIG64(AssignCond__DOT__dout,60,0);
    
    // LOCAL VARIABLES
    // Internals; generally not touched by application code
    VL_SIG8(__Vclklast__TOP___clock,0,0);
    VL_SIG8(__Vclklast__TOP___resetn,0,0);
    
    // INTERNAL VARIABLES
    // Internals; generally not touched by application code
    VAssignCond__Syms* __VlSymsp;  // Symbol table
    
    // PARAMETERS
    // Parameters marked /*verilator public*/ for use by application code
    
    // CONSTRUCTORS
  private:
    VAssignCond& operator= (const VAssignCond&);  ///< Copying not allowed
    VAssignCond(const VAssignCond&);  ///< Copying not allowed
  public:
    /// Construct the model; called by application code
    /// The special name  may be used to make a wrapper with a
    /// single model invisible WRT DPI scope names.
    VAssignCond(const char* name="TOP");
    /// Destroy the model; called (often implicitly) by application code
    ~VAssignCond();
    
    // API METHODS
    /// Evaluate the model.  Application must call when inputs change.
    void eval();
    /// Simulation complete, run final blocks.  Application must call on completion.
    void final();
    
    // INTERNAL METHODS
  private:
    static void _eval_initial_loop(VAssignCond__Syms* __restrict vlSymsp);
  public:
    void __Vconfigure(VAssignCond__Syms* symsp, bool first);
  private:
    static QData _change_request(VAssignCond__Syms* __restrict vlSymsp);
    void _configure_coverage(VAssignCond__Syms* __restrict vlSymsp, bool first);
    void _ctor_var_reset();
  public:
    static void _eval(VAssignCond__Syms* __restrict vlSymsp);
    static void _eval_initial(VAssignCond__Syms* __restrict vlSymsp);
    static void _eval_settle(VAssignCond__Syms* __restrict vlSymsp);
    static void _sequent__TOP__1(VAssignCond__Syms* __restrict vlSymsp);
    static void _settle__TOP__2(VAssignCond__Syms* __restrict vlSymsp);
} VL_ATTR_ALIGNED(128);

#endif // guard
