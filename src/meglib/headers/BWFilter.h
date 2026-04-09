#ifndef FILTER_DEFS_H
#define FILTER_DEFS_H

/*document version history
1.2	- code beautifying
*/

#include 		<math.h>
#define P 		2*(MAXORDER+1)

#ifndef M_PI
#define M_PI 	3.141592654
#endif
static	int		FILTER_INITIALIZED = false;
#define MAXORDER	20

/* filter type definitions */
enum { BW_LOWPASS = 0, BW_HIGHPASS, BW_BANDPASS, BW_BANDREJECT };

typedef struct	filter_params {
	int			enable;			/* D. Cheyne - added flag to turn filter on or off - simplifies code that receives filter_params struct */
	int			type;			/* filter type */
	bool		bidirectional;	/* use forward-backward to reduce phase shift */
	double		hc;				/* high edge filter frequency (Hz) */
	double		lc;				/* low edge filter frequency (Hz) */
	double		fs;				/* sample rate (Hz) */
	int			order;			/* filter order */
	int			ncoeff;			/* number of coefficient pairs */
	double		num[MAXORDER];	/* numerator iir coefficients */
	double		den[MAXORDER];	/* denominator iir coefficients */
} filter_params;

int applyFilter( double *in, double *out, int nsamples, filter_params *fp );
int build_filter( filter_params *fp );
//int Filter( double *in, double *out, int ns, filter_params *fp );

#endif
