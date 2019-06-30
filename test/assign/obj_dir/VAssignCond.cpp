// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See VAssignCond.h for the primary calling header

#include "VAssignCond.h"       // For This
#include "VAssignCond__Syms.h"


//--------------------
// STATIC VARIABLES


//--------------------

VL_CTOR_IMP(VAssignCond) {
    VAssignCond__Syms* __restrict vlSymsp = __VlSymsp = new VAssignCond__Syms(this, name());
    VAssignCond* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Reset internal values
    
    // Reset structure values
    _ctor_var_reset();
}

void VAssignCond::__Vconfigure(VAssignCond__Syms* vlSymsp, bool first) {
    if (0 && first) {}  // Prevent unused
    this->__VlSymsp = vlSymsp;
}

VAssignCond::~VAssignCond() {
    delete __VlSymsp; __VlSymsp=NULL;
}

//--------------------


void VAssignCond::eval() {
    VAssignCond__Syms* __restrict vlSymsp = this->__VlSymsp;  // Setup global symbol table
    VAssignCond* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Initialize
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) _eval_initial_loop(vlSymsp);
    // Evaluate till stable
    VL_DEBUG_IF(VL_PRINTF("\n----TOP Evaluate VAssignCond::eval\n"); );
    int __VclockLoop = 0;
    QData __Vchange = 1;
    while (VL_LIKELY(__Vchange)) {
	VL_DEBUG_IF(VL_PRINTF(" Clock loop\n"););
	_eval(vlSymsp);
	__Vchange = _change_request(vlSymsp);
	if (VL_UNLIKELY(++__VclockLoop > 100)) vl_fatal(__FILE__,__LINE__,__FILE__,"Verilated model didn't converge");
    }
}

void VAssignCond::_eval_initial_loop(VAssignCond__Syms* __restrict vlSymsp) {
    vlSymsp->__Vm_didInit = true;
    _eval_initial(vlSymsp);
    int __VclockLoop = 0;
    QData __Vchange = 1;
    while (VL_LIKELY(__Vchange)) {
	_eval_settle(vlSymsp);
	_eval(vlSymsp);
	__Vchange = _change_request(vlSymsp);
	if (VL_UNLIKELY(++__VclockLoop > 100)) vl_fatal(__FILE__,__LINE__,__FILE__,"Verilated model didn't DC converge");
    }
}

//--------------------
// Internal Methods

VL_INLINE_OPT void VAssignCond::_sequent__TOP__1(VAssignCond__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_PRINTF("    VAssignCond::_sequent__TOP__1\n"); );
    VAssignCond* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    // ALWAYS at AssignCond.v:23
    vlTOPp->AssignCond__DOT__dout = (VL_ULL(0x1fffffffffffffff) 
				     & ((IData)(vlTOPp->_resetn)
					 ? (vlTOPp->add1 
					    + vlTOPp->add2)
					 : VL_ULL(0)));
    vlTOPp->dout_q = vlTOPp->AssignCond__DOT__dout;
}

void VAssignCond::_settle__TOP__2(VAssignCond__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_PRINTF("    VAssignCond::_settle__TOP__2\n"); );
    VAssignCond* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    vlTOPp->dout_q = vlTOPp->AssignCond__DOT__dout;
}

void VAssignCond::_eval(VAssignCond__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_PRINTF("    VAssignCond::_eval\n"); );
    VAssignCond* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    if ((((IData)(vlTOPp->_clock) & (~ (IData)(vlTOPp->__Vclklast__TOP___clock))) 
	 | ((~ (IData)(vlTOPp->_resetn)) & (IData)(vlTOPp->__Vclklast__TOP___resetn)))) {
	vlTOPp->_sequent__TOP__1(vlSymsp);
    }
    // Final
    vlTOPp->__Vclklast__TOP___clock = vlTOPp->_clock;
    vlTOPp->__Vclklast__TOP___resetn = vlTOPp->_resetn;
}

void VAssignCond::_eval_initial(VAssignCond__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_PRINTF("    VAssignCond::_eval_initial\n"); );
    VAssignCond* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void VAssignCond::final() {
    VL_DEBUG_IF(VL_PRINTF("    VAssignCond::final\n"); );
    // Variables
    VAssignCond__Syms* __restrict vlSymsp = this->__VlSymsp;
    VAssignCond* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void VAssignCond::_eval_settle(VAssignCond__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_PRINTF("    VAssignCond::_eval_settle\n"); );
    VAssignCond* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    vlTOPp->_settle__TOP__2(vlSymsp);
}

VL_INLINE_OPT QData VAssignCond::_change_request(VAssignCond__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_PRINTF("    VAssignCond::_change_request\n"); );
    VAssignCond* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    // Change detection
    QData __req = false;  // Logically a bool
    return __req;
}

void VAssignCond::_ctor_var_reset() {
    VL_DEBUG_IF(VL_PRINTF("    VAssignCond::_ctor_var_reset\n"); );
    // Body
    add1 = VL_RAND_RESET_Q(60);
    add2 = VL_RAND_RESET_Q(60);
    dout_q = VL_RAND_RESET_Q(61);
    _clock = VL_RAND_RESET_I(1);
    _resetn = VL_RAND_RESET_I(1);
    AssignCond__DOT__dout = VL_RAND_RESET_Q(61);
    __Vclklast__TOP___clock = VL_RAND_RESET_I(1);
    __Vclklast__TOP___resetn = VL_RAND_RESET_I(1);
}

void VAssignCond::_configure_coverage(VAssignCond__Syms* __restrict vlSymsp, bool first) {
    VL_DEBUG_IF(VL_PRINTF("    VAssignCond::_configure_coverage\n"); );
    // Body
    if (0 && vlSymsp && first) {} // Prevent unused
}
