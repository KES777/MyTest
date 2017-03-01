
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"



MODULE = MyTest    PACKAGE = MyTest


SV*
get_package()
PPCODE:
    const PERL_CONTEXT *cx =  caller_cx(0, NULL);
    printf( "2.1 %p\n", cx );
