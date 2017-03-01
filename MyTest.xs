
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"


/* https://st.aticpan.org/source/ETHER/B-OPCheck-0.32/OPCheck.xs */
/* ============================================
   This is from Runops::Hook.  We need to find a way to share c functions
*/

STATIC int Runops_Trace_loaded_B;
STATIC CV *Runops_Trace_B_UNOP_first;
STATIC XSUBADDR_t Runops_Trace_B_UNOP_first_xsub;
STATIC UNOP Runops_Trace_fakeop;
STATIC SV *Runops_Trace_fakeop_sv;

STATIC void
Runops_Trace_load_B (pTHX) {
    if (!Runops_Trace_loaded_B) {
        load_module( PERL_LOADMOD_NOIMPORT, newSVpv("B", 0), (SV *)NULL );

        Runops_Trace_B_UNOP_first = get_cv("B::UNOP::first", TRUE);
        Runops_Trace_B_UNOP_first_xsub = CvXSUB(Runops_Trace_B_UNOP_first);

        Runops_Trace_fakeop_sv = sv_bless(newRV_noinc(newSVuv((UV)&Runops_Trace_fakeop)), gv_stashpv("B::UNOP", 0));

        Runops_Trace_loaded_B = 1;
    }
}

STATIC SV *
Runops_Trace_op_to_BOP (pTHX_ OP *op) {
    dSP;

    /* we fake B::UNOP object (fakeop_sv) that points to our static fakeop.
     * then we set first_op to the op we want to make an object out of, and
     * trampoline into B::UNOP->first so that it creates the B::OP of the
     * correct class for us.
     * B should really have a way to create an op from a pointer via some
     * external API. This sucks monkey balls on olympic levels */

    Runops_Trace_fakeop.op_first = op;

    PUSHMARK(SP);
    XPUSHs(Runops_Trace_fakeop_sv);
    PUTBACK;

    /* call_pv("B::UNOP::first", G_SCALAR); */
    assert(Runops_Trace_loaded_B);
    assert(Runops_Trace_B_UNOP_first);
    assert(Runops_Trace_B_UNOP_first_xsub != NULL);
    (void)Runops_Trace_B_UNOP_first_xsub(aTHX_ Runops_Trace_B_UNOP_first);

    SPAGAIN;

    return POPs;
}

/* ============================================
   End of Runops::Hook.  We need to find a way to share c functions
*/

void
// call_callback2(pTHX_ SV *sub, OP *o) {
call_callback2(pTHX_ OP *o) {
    SV *PL_op_object;
    dSP;

    ENTER;
    SAVETMPS;


    printf( "1\n" );
    PL_op_object = Runops_Trace_op_to_BOP(aTHX_ o);

    PUSHMARK(SP);
    XPUSHs(PL_op_object);

    PUTBACK;

    //call_sv(sub, G_DISCARD);
    call_pv("MyTest::mysub", G_DISCARD);

    SPAGAIN;

    PUTBACK;
    FREETMPS;
    LEAVE;

}



/* http://perldoc.perl.org/perlcall.html#No-Parameters%2c-Nothing-Returned */
static void call_callback() {
    dSP;

    PUSHMARK(SP);
    call_pv("MyTest::mysub", G_DISCARD|G_NOARGS);
}


/* The ckfunc we're replacing */
static Perl_check_t old_checker;
static int reentrance;
static OP *my_check(pTHX_ OP *op) {
      if( reentrance > 0 )
    return old_checker(op);


    reentrance =  reentrance +1;
    printf( "PAD*: %d -- %d\n", op->op_type, reentrance );



    // call_callback();
    // call_callback2(aTHX_ op );

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
    reentrance =  reentrance -1;
    return old_checker(op);
}

char* curr_package() {
    int count;

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);

    PUTBACK;
    count =  call_pv( "MyTest::get_package", G_SCALAR );

    SPAGAIN;
    if( count != 1 )
        croak("Big trouble\n");

    char *pn =  POPp;

    PUTBACK;
    FREETMPS;
    LEAVE;

    return pn;
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
    // wrap_op_checker(OP_ENTERSUB, my_check, &old_checker);

    // old_rpeepp = PL_rpeepp;
    // PL_rpeepp   = my_rpeep;

    // Runops_Trace_load_B(aTHX);


SV*
tc()
PPCODE:
    // PUSHi( 42 );
    // XPUSHs(sv_2mortal(newSViv(42)));
    // mXPUSHs( newSViv( 42 ) );

    // XPUSHs(newSViv(42)); // Possibly memory leak
    // dMY_CXT;
    const PERL_CONTEXT *cx =  caller_cx(0, NULL);
    printf( "2.1 %p\n", cx );

    char * name =  curr_package();
    printf( "Name: %s\n", name );
    SV* sv;
    sv =  newSVpvs( "Hello" );
    // sv =  newSVpv( name, 0 );
    mXPUSHs( sv );
