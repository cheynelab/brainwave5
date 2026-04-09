#include "../headers/complex_math.h"


/*document version history
1.2	- code beautifying

Kash
1.3	- complex function updates
*/

COMPLEX	Cadd(		// complex add: a + b
	COMPLEX	a,
	COMPLEX	b
)

{
	COMPLEX	c;

	c.r = a.r + b.r;
	c.i = a.i + b.i;
	return c;
}

COMPLEX	Csub(		// complex subtract: a - b
	COMPLEX	a,
	COMPLEX	b
)

{
	COMPLEX	c;

	c.r = a.r - b.r;
	c.i = a.i - b.i;
	return c;
}

COMPLEX	Cmul(		// complex multiply: a * b
	COMPLEX	a,
	COMPLEX	b
)

{
	COMPLEX	c;

	c.r = a.r * b.r - a.i * b.i;
	c.i = a.i * b.r + a.r * b.i;
	return c;
}

COMPLEX	Cdiv(		// complex divide: a / b
	COMPLEX	a,
	COMPLEX	b
)

{
	COMPLEX	c;
	double	den;

	if(b.r == 0. && b.i == 0.) {
		c.r = c.i = HUGE_VAL;
		return c;
	}
	den = 1. / (b.r * b.r + b.i * b.i);
	c.r = (a.r * b.r + a.i * b.i) * den;
	c.i = (a.i * b.r - a.r * b.i) * den;
	return c;
}

COMPLEX	Cset(		// set complex number
	double	re,
	double	im
)

{
	COMPLEX	c;

	c.r = re;
	c.i = im;
	return c;
}

double	Cabs(		// absolute value of complex number
	COMPLEX	a
)

{
	return sqrt(a.r * a.r + a.i * a.i);
}

COMPLEX	Csqrt(		// square root of a
	COMPLEX	a
)

{
	COMPLEX	b;
	double	ar;
	double	ai;
	double	r;
	double	w;

	if(a.r == 0. && a.i == 0.) {
		b.r = b.i = 0.;
		return b;
	}
	ar = fabs(a.r); ai = fabs(a.i);
	if(ar >= ai) {
		r = ai / ar;
		w = sqrt(ar) * sqrt(.5 * (1. + sqrt(1. + r * r)));
	} else {
		r = ar / ai;
		w = sqrt(ai) * sqrt(.5 * (r + sqrt(1. + r * r)));
	}
	if(a.r >= 0.) {
		b.r = w;
		b.i = a.i / (2. * b.r);
	} else {
		b.i = (a.i >= 0.) ? w : -w;
		b.r = a.i / (2. * b.i);
	}
	return b;
}

COMPLEX	Cexp(		// complex exponential of a
	double	a
)

{
	COMPLEX	b;

	b.r = cos(a);
	b.i = sin(a);
	return b;
}

COMPLEX	Conj(		// complex conjugate of a
	COMPLEX	a
)

{
	COMPLEX	b;

	b.r = a.r;
	b.i = -a.i;
	return b;
}

COMPLEX	Bilin(		// bilinear transform from s to z
	COMPLEX	a
)

{
	return Cdiv(Cadd(COMPLEX_ONE, a), Csub(COMPLEX_ONE, a));
}

COMPLEX	Cscale(		// scale complex number by multiplying by real
	double	a,
	COMPLEX	b
)

{
	COMPLEX	c;

	c.r = a * b.r;
	c.i = a * b.i;
	return c;
}
