
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"


/* http://perldoc.perl.org/perlcall.html#No-Parameters%2c-Nothing-Returned */
static void call_callback() {
    dSP;

    PUSHMARK(SP);
    call_pv("MyTest::mysub", G_DISCARD|G_NOARGS);
}


/* The ckfunc we're replacing */
static Perl_check_t old_checker;
static OP *my_check(pTHX_ OP *op) {
    printf( "PAD*: %d\n", op->op_type );
    call_callback();

    SV *sv = cSVOPx_sv(op);
    if (sv) {
        SV *cmp = sv_2mortal(newSVpvs("Hello world"));

        if (sv_eq(sv, cmp)) {
            SvREADONLY_off(sv);
            sv_setpv(sv, "Hello Perl");
            SvREADONLY_on(sv);
        }
    }

    /* Let the previous ckfunc do its work */
    return old_checker(op);
}


/* http://perldoc.perl.org/perlguts.html#Compile-pass-3%3a-peephole-optimization */
static peep_t old_rpeepp;
static void my_rpeep(pTHX_ OP *o)
{
    OP *orig_o = o;
    for(; o; o = o->op_next) {
        printf( "OP: %d\n", o->op_type );
        call_callback();
        /* custom per-op optimisation goes here */
    }
    old_rpeepp(aTHX_ orig_o);
}

MODULE = MyTest    PACKAGE = MyTest

BOOT:
    wrap_op_checker(OP_PADANY, my_check, &old_checker);

    old_rpeepp = PL_rpeepp;
    PL_rpeepp   = my_rpeep;
