#ifndef VECTOR_MATH_H
#define VECTOR_MATH_H

#include <math.h>

const double		TINY_NO	= 1.0e-20;

#define	xAxis		1
#define	yAxis		2
#define	zAxis		3

#define CCW			0
#define CW			1

// #define true		1
// #define false		0

typedef struct vectorCart {
	double x;
	double y;
	double z;
} vectorCart;

typedef struct vectorSph {
	double azimuth;
	double declination;
	double radius;
} vectorSph;

typedef struct matrix {
	double	m[3][3];		// convention is [column][row]
} matrix;

// *new from Jan, 2014 - added structure and routines for 4 x 4 affine matrix = indexing is [row][column]
typedef struct affine {
	double	m[4][4];
} affine;

affine      affineIdentityMatrix(void);
vectorCart  vectorXaffine( vectorCart v1, affine m );
affine      affineXaffine( affine m1, affine m2 );

/////

double 			Deg2Rad ( double );
double 			Rad2Deg ( double );
void			eulerToDirectionCosines( double , double, double, 
							vectorCart *, vectorCart *, vectorCart * );
matrix 			setRotationMatrix( vectorCart, vectorCart, vectorCart );
matrix 			createRotationMatrix( int, int, double );
vectorCart		vectorXmatrix( vectorCart, matrix );
matrix			matrixXmatrix( matrix, matrix );
double			vectorLength ( vectorCart );
vectorCart		unitVector ( vectorCart );
matrix			identityMatrix( void );
vectorCart		subtractVectors( vectorCart, vectorCart );
vectorCart		addVectors( vectorCart, vectorCart );
vectorCart		scaleVector ( vectorCart, double );
vectorCart		makeOrthogonalTo( vectorCart, vectorCart );
double 			vectorDotProduct( vectorCart, vectorCart);			
vectorCart 		vectorCrossProduct( vectorCart, vectorCart);			
matrix			transposeMatrix( matrix );
vectorSph 		cartesian2spherical( vectorCart );
vectorCart 		spherical2cartesian( vectorSph );

bool                    invertMatrix2D( double m[2][2] );
bool			invertMatrix( double **, double **, int );
bool 			ludcmp(double **a, int n, int *indx, double *d);
void 			lubksb(double **a, int n, int *indx, double *b);
bool			equalVectors( vectorCart, vectorCart );


#endif
