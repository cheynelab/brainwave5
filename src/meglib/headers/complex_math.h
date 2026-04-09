#ifndef H_COMPLEX
#define H_COMPLEX

/*document version history
1.2	- code beautifying
*/

#include <stdlib.h>
#include <math.h>

// definition of a complex variable
typedef struct	COMPLEX {
	double	r;
	double	i;
} COMPLEX;

// complex arithmetic operations
double		Cabs(COMPLEX);
COMPLEX		Cadd(COMPLEX, COMPLEX);
COMPLEX		Csub(COMPLEX, COMPLEX);
COMPLEX		Cmul(COMPLEX, COMPLEX);
COMPLEX		Cdiv(COMPLEX, COMPLEX);
COMPLEX		Cset(double, double);
COMPLEX		Csqrt(COMPLEX);
COMPLEX		Cexp(double);
COMPLEX		Conj(COMPLEX);
COMPLEX		Bilin(COMPLEX);
COMPLEX		Cscale(double, COMPLEX);

//convenient definitions
#define COMPLEX_ZERO	Cset(0., 0.)
#define COMPLEX_ONE	Cset(1., 0.)
#define COMPLEX_MONE	Cset(-1., 0.)

#ifndef TRUE
#define TRUE	1
#endif

#ifndef FALSE
#define FALSE	0
#endif

#endif	// H_COMPLEX
