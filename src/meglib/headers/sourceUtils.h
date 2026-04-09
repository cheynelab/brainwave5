#ifndef SOURCE_UTILS_H
#define SOURCE_UTILS_H

#include <pthread.h>
#include "../headers/vectorMath.h"
#include "../headers/datasetUtils.h"

typedef struct dip_params
{
	double		moment;
	double		xpos;
	double		ypos;
	double		zpos; 
	double		xori;
	double		yori;
	double		zori;
} dip_params;

void            sortDoubleArray( double *vector, int vectorSize);
void            printPercentDone( int iter, int numIter);
void			initGaussianDeviate(void);
double			getGaussianDeviate(void);
double			getRandom(void);
double			ran1(long *idum);

bool			init_dsParams( ds_params & dsParams, double *sphereX, double *sphereY, double *sphereZ,  char *hdmFile, bool useHdmFile );

bool			readHdmFile( char *fileName, ds_params & dsParams, double *sphereX, double *sphereY, double *sphereZ);

bool            computeForwardSolution( const ds_params & dsParams, const dip_params & dipParams, 
									   double *dipPattern, bool includeBalancingRefs, int gradient, bool computeMagnetic, bool useDewar);

double          computeFieldMagnetic(const dip_params & dipParams, const channelRec & channel, bool useDewar );
double          computeField(const dip_params & dipParams, const channelRec & channel );
int 			runSimplexFit( int num_param,
				  double *param_array,
				  double *delta_array,
				  double (*ErrorFunction)(double *param_array),
				  int maximum_iter, double tolerance);

#endif
