#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "execinfo.h"

#include "ppport.h"

/* The ckfunc we're replacing */
static Perl_check_t old_checker;

static void call_mysub() {
    dSP;

    fprintf(stderr, "Keyword\n");
    PUSHMARK(SP);
    call_pv("MyTest::mysub", G_DISCARD|G_NOARGS);
}

static void my_trace() {
    void* callstack[128];
    int i, frames;
    char** strs;

    fprintf(stderr, "STACK XS\n");
  frames = backtrace(callstack, 128);
  strs = backtrace_symbols(callstack, frames);
  for (i = 0; i < frames; ++i) {
      fprintf(stderr, "%s\n", strs[i] );
  }
  free( strs );

}

/* Our replacement function. This will modify an OP_CONST
 * if it matches a certain string. Note that this is only
 * called when the OP_CONST is compiled, not when it is
 * executed.
 */

static OP *my_check(pTHX_ OP *op) {
    SV *sv = cSVOPx_sv(op);
    OP *old;

    int offset =  cPADOPx(op)->op_padix;

    PADOFFSET padoff;
    padoff = op->op_targ;
    PAD_COMPNAME_GEN_set(padoff, PERL_INT_MAX);
    if (padoff) {
        PADNAME * const pn = PAD_COMPNAME(padoff);  /*PAD_COMPNAME_SV*/
        const char * const name = PadnamePV(pn);
        fprintf(stderr, name);
    }


    fprintf(stderr, "Keyword %d\n", padoff);
    my_trace();

    // call_mysub();

    if (sv) {
        SV *cmp = sv_2mortal(newSVpvs("Hello world"));

        if (sv_eq(sv, cmp)) {
            SvREADONLY_off(sv);
            sv_setpv(sv, "Hello Perl");
            SvREADONLY_on(sv);
        }
    }

    /* Let the previous ckfunc do its work */
    fprintf(stderr, "PRE\n" );
    old = old_checker(op);

    fprintf(stderr, "Keyword OLD %d\n", old->op_type);

    return old;
}


MODULE = MyTest     PACKAGE = MyTest

BOOT:
wrap_op_checker(OP_PADANY, my_check, &old_checker);
