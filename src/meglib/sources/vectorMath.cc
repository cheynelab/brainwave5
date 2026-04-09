////////////////////////////////////////////////////
//	file vectorMath.cc
//	some basic operations on vectors and matrices
//  (c) D. Cheyne, 2003-2012 All rights reserved. 
///////////////////////////////////////////////////

#include <stdio.h>
#include <stdlib.h>
#include "../headers/vectorMath.h"


// April 5, 2005 	- added routines for inverting matrices from Numerical Recipes
//

const double pie = acos(-1);

///////
// Jan, 2014        - added functions for transformation with 4 x 4 affine matrix
//                    note that indexing convention for affine matrix is [row][column] whereas older routines
//                    assume [column][row] index order.

// postmultiplication of 3 dimensional vectorCart with 4 x 4 affine transformation matrix

affine
affineIdentityMatrix(void)
{
    affine m;
	// initialize m to identity matrix
	for (int i=0; i<4; i++)
	{
		for (int j=0; j<4; j++)
		{
			if (i == j)
				m.m[i][j] = 1.0;
			else
				m.m[i][j] = 0.0;
        }
        
	}
	return m;
}

vectorCart
vectorXaffine( vectorCart v1, affine m )
{
    double      v[4];
	vectorCart	result;
    
    v[0] = v1.x;
    v[1] = v1.y;
    v[2] = v1.z;
    v[3] = 1.0;
    
	result.x = v[0] * m.m[0][0] + v[1] * m.m[1][0] + v[2] * m.m[2][0] + v[3] * m.m[3][0];
	result.y = v[0] * m.m[0][1] + v[1] * m.m[1][1] + v[2] * m.m[2][1] + v[3] * m.m[3][1];
	result.z = v[0] * m.m[0][2] + v[1] * m.m[1][2] + v[2] * m.m[2][2] + v[3] * m.m[3][2];
	// returning 3d vector - omit last multiplication
    
	return result;
}

// note post-multiplication assumes order is [row][column]
affine
affineXaffine( affine m1, affine m2 )
{
    affine result;
    
    for (int i=0; i<4; i++)
    {
        for (int j=0; j<4; j++)
        {
            result.m[i][j] = 0.0;
            for (int k=0; k<4; k++)
                result.m[i][j] += m1.m[i][k] * m2.m[k][j];
        }
    }
    
    return result;
}

//////


vectorCart	
vectorXmatrix( vectorCart v, matrix m )	
{
	vectorCart		result;

	// multiply vector row vector by each column of matrix
	// note that matrix is stored [column][row]
	// 
	result.x = v.x * m.m[0][0] + v.y * m.m[0][1] + v.z * m.m[0][2];
	result.y = v.x * m.m[1][0] + v.y * m.m[1][1] + v.z * m.m[1][2];
	result.z = v.x * m.m[2][0] + v.y * m.m[2][1] + v.z * m.m[2][2];
	
	return ( result );
}

matrix	
matrixXmatrix( matrix m1, matrix m2 )	
{
	matrix result;
	int	i, j, k;

	for (i=0; i<3; i++)
	{
		for (j=0; j<3; j++) 
		{
			result.m[i][j] = 0.0;
			for (k=0; k<3; k++)
				result.m[i][j] += m1.m[k][j] * m2.m[i][k];
		}
	}
		
	return ( result );
}

// makes returna a new copy of vector a whichis orthogonal to b		
vectorCart 
makeOrthogonalTo( vectorCart a, vectorCart b )			
{	
	vectorCart	c;
	double	length, cosang;

	length = vectorLength( a );
	vectorCart aa = unitVector( a );
	vectorCart bb = unitVector( b );
	 
	cosang = vectorDotProduct( bb, aa );

	aa.x -= cosang * bb.x;
	aa.y -= cosang * bb.y;
	aa.z -= cosang * bb.z;
	c = unitVector( aa );
	
	// scale back to original length
	c.x *= length;
	c.y *= length;
	c.z *= length;
	
	return ( c );	
}

vectorCart 
unitVector( vectorCart a )
{
	double 	length;
	vectorCart	b = a;	
	double r = (a.x * a.x) + (a.y * a.y) + (a.z * a.z);
	if ( r > TINY_NO ) 
	{
		length = sqrt( r );
		b.x /= length;
		b.y /= length;
		b.z /= length;
	}
	
	return( b );
}

// a plus b
vectorCart 
addVectors( vectorCart a, vectorCart b )			
{
	vectorCart c;
	
	c.x = a.x + b.x;
	c.y = a.y + b.y;
	c.z = a.z + b.z;

	return ( c );		
}

// Does a==b?
bool
equalVectors( vectorCart a, vectorCart b )
{
	if ( a.x != b.x ||
	     a.y != b.y ||
	     a.z != b.z )
	{
		return ( false );
	}
	else
	{
		return ( true );
	}
}

// a plus b
vectorCart 
scaleVector( vectorCart a, double scale )			
{
	vectorCart c;
	
	c.x = a.x * scale;
	c.y = a.y * scale;
	c.z = a.z * scale;

	return ( c );		
}


// a minus b
vectorCart 
subtractVectors( vectorCart a, vectorCart b )			
{
	vectorCart c;
	
	c.x = a.x - b.x;
	c.y = a.y - b.y;
	c.z = a.z - b.z;

	return ( c );		
}


double 
vectorLength( vectorCart a )			
{
	double 	r;
	double	length = 0.0;
	
	r = (a.x * a.x) + (a.y * a.y) + (a.z * a.z);
	if ( r > TINY_NO ) 
		length = sqrt( r );

	return (length);		
}

double 
vectorDotProduct( vectorCart a, vectorCart b)			
{
	double 	dot;
	
	dot = (a.x * b.x) + (a.y * b.y) + (a.z * b.z);

	return ( dot );		
}

vectorCart 
vectorCrossProduct( vectorCart a, vectorCart b )			
{
	vectorCart c;
	
	c.x = a.y * b.z - a.z * b.y;
	c.y = a.z * b.x - a.x * b.z;
	c.z = a.x * b.y - a.y * b.x;

	return ( c );		
}

matrix	
transposeMatrix( matrix m )	
{
	matrix result;
	int	i, j;

	for (i=0; i<3; i++)
		for (j=0; j<3; j++) 
			result.m[i][j] = m.m[j][i];
		
	return ( result );
}

matrix 
identityMatrix( void )
{
	matrix m;
	
	// initialize m to identity matrix
	for (int i=0; i<3; i++)
	{
		for (int j=0; j<3; j++)
		{
			if (i == j)
				m.m[i][j] = 1.0;
			else
				m.m[i][j] = 0.0;
        }
        
	}
	return m;
}

// convert euler rotation angles to direction cosines (attitude matrix)
//	( from Polhemus manual )
//
void 
eulerToDirectionCosines( 	double azimuth, double elevation, double roll,
								vectorCart *v1, vectorCart *v2, vectorCart *v3 )
{
	vectorCart x;
	vectorCart y;
	vectorCart z;
	
	double SA = sin( azimuth );
	double SE = sin( elevation );
	double SR = sin( roll );	

	double CA = cos( azimuth );
	double CE = cos( elevation );
	double CR = cos( roll );	
	
	x.x = CA * CE;
	x.y = SA * CE;
	x.z = -SE;
	
	y.x = ( CA * SE * SR ) - ( SA * CR );
	y.y = ( CA * CR ) + ( SA * SE * SR );
	y.z = CE * SR;

	z.x = ( CA * SE * CR ) + ( SA * SR );
	z.y = ( SA * SE * CR ) - ( CA * SR );
	z.z = CE * CR;
	
	*v1 = x;
	*v2 = y;
	*v3 = z;
	 
}

// make rotation matrix directly from direction cosines
//
matrix 
setRotationMatrix( vectorCart v1, vectorCart v2, vectorCart v3 )
{
	matrix 		m;
						
	m.m[0][0] = v1.x;
	m.m[1][0] = v1.y;
	m.m[2][0] = v1.z;

	m.m[0][1] = v2.x;
	m.m[1][1] = v2.y;
	m.m[2][1] = v2.z;

	m.m[0][2] = v3.x;
	m.m[1][2] = v3.y;
	m.m[2][2] = v3.z;

	return ( m );
}

// axis = axis of rotation 
// direction = direction of rotation about axis looking toward origin along axis
//
matrix 
createRotationMatrix( int axis, int direction, double theta )
{
	matrix 		m;
	
	// default direction of rotation is CW,  can reverse direction of rotatino
	// by negating angle of rotation
	//
	if ( direction == CCW )
		theta *= -1.0;
		
	m = identityMatrix();
					
	switch ( axis ) 
	{
	  case xAxis:
		m.m[1][1] = cos(theta);
		m.m[1][2] = sin(theta);
		m.m[2][1] = -sin(theta);
		m.m[2][2] = cos(theta);
		break;
	  case yAxis: 
		m.m[0][0] = cos(theta);
		m.m[0][2] = -sin(theta);
		m.m[2][0] = sin(theta);
		m.m[2][2] = cos(theta);
		break;
	  case zAxis:
		m.m[0][0] = cos(theta);
		m.m[0][1] = sin(theta);
		m.m[1][0] = -sin(theta);
		m.m[1][1] = cos(theta);
		break;
	};
	
	return ( m );

}

double 
Deg2Rad ( double angle ) 
{
	return  ( (angle / 180.0 ) * pie );
}

double 
Rad2Deg ( double angle ) 
{
	return  ( (angle / pie ) * 180.0 );
}

vectorSph 
cartesian2spherical( vectorCart a )
{
	double 		h2, temp;
	double 		r, t, p;
	vectorSph	result;
	
	
	h2 = a.x * a.x + a.y * a.y;
	temp = h2 + a.z * a.z;
	
	r = sqrt(temp);
	
	// case x and y very close to zero 
	if ( h2 < TINY_NO ) {	
		t = 0.0;
		if (a.z < 0.0)
			p = pie;
		else
			p = 0.0;
	}
	else 
	{
		// case z very close to zero 
		if ( fabs(a.z) < TINY_NO ) 	
			p = pie/2.0;
		else 
		{
			temp = (sqrt(h2)) / a.z;
			p = atan(temp);
			if (a.z < 0.0)
				p += pie;
		}
		
		if ( fabs(a.x) < TINY_NO ) 
		{	
			// case x very close to zero 
			if (a.y > 0.0) 
				t = pie/2.0;
			else
				t = ( 3.0*pie ) / 2.0;
		}
		else if ( fabs(a.y) < TINY_NO ) 
		{	
			// case y very close to zero 
			if (a.x > 0.0) 
				t = 0.0;
			else
				t = pie;
		}
		else 
		{						
			temp = a.x / (sqrt(h2));
			t = acos(temp);
			if (a.y < 0.0)
				t = ( 2.0*pie ) - t;
		}
	}
	
	result.radius = r;
	result.azimuth = t;		
	result.declination = p;		
	
	return (result);
}

vectorCart 
spherical2cartesian ( vectorSph a )
{
	vectorCart 	b;
	
	double hyp = a.radius * sin(a.declination);
	
	b.y = hyp * sin(a.azimuth);
	b.x = hyp * cos(a.azimuth);
	b.z = a.radius * cos(a.declination);

	return (b);
}

// do  in-place inverse of 2 x 2 matrix 
// [a b; c d]' = 1/det * [d -c; -b a]
//
bool invertMatrix2D(double m[2][2])
{
        double det = (m[0][0] * m[1][1] ) - (m[0][1] * m[1][0]);
        if (det == 0.0)
        {
                printf("singular matrix passed to invertMatrix2D\n");
                return(false);
        }
        double a = m[0][0];  // don't overwrite 
        double d = m[1][1];
        double t = 1.0 / det;
        
        m[0][0] = t * d;
        m[0][1] = t * -m[0][1];
        m[1][0] = t * -m[1][0];
        m[1][1] = t * a;
        
        return (true);
}

// D. Cheyne, Mar 14, 2005

// routines to invert matrix using LU decomposition from Numerical Recipes
// y is returned as inverse of a where a is a N x N square matrix
// note all NR code assumes Fortran based indexing starts at 1
// -- modified so that matrices can be passed where indexing starts from zero instead of 1
//    as a result a is also not destroyed in the process
//    otherwise, NR code unchanged except floats replaced with doubles, and vector with malloc

bool invertMatrix(double **a, double **y, int N )
{

	double 		d;
	double 		**acopy;
	double		*col;
	int		*indx;
	
	col = (double *)malloc( (N+1) * sizeof(double));	
	if ( col == NULL )
	{
		printf("Error allocating memory for matrix inverse\n");
		return (false);
	}

	indx = (int *)malloc( (N+1) * sizeof(int) );	
	if ( indx == NULL )
	{
		printf("Error allocating memory for matrix inverse\n");
		return (false);
	}

	acopy = (double **)malloc( (N+1) * sizeof(double *));	
	if ( acopy  == NULL )
	{
		printf("Error allocating memory for matrix inverse\n");
		return (false);
	}
	for (int i=0; i<(N+1); i++)
	{
		acopy[i] = (double *)malloc( (N+1) * sizeof(double));	
		if ( acopy[i]  == NULL )
		{
			printf("Error allocating memory for matrix inverse\n");
			return (false);
		}
	}

	// make a copy of passed matrix with indexing starting at 1
	// so it can be passed directly to NR routines
	//
	for (int i=0; i<N; i++)
		for (int j=0; j<N; j++)		
			acopy[i+1][j+1] = a[i][j];	

	// Decompose the matrix just once.

	if ( !ludcmp(acopy, N, indx, &d) )
	{
		printf("ludcmp failed...\n");
		free( col );
		free (indx);
		for (int i=0; i<N+1; i++)
			free(acopy[i]);
		free(acopy);
		
		return (false);
	}

	for(int j=1;j<=N;j++) 
	{ 	
		for(int i=1;i<=N;i++) 
			col[i]=0.0;
		col[j]=1.0;
		
		lubksb(acopy,N,indx,col);

		for(int i=1;i<=N;i++) 
			y[i-1][j-1]=col[i];	// ** note indexing changed for y		
	}	

	// printf("freeing memory...\n");
	free( col );
	free (indx);
	for (int i=0; i<N+1; i++)
		free(acopy[i]);
	free(acopy);

	return (true);
}

void lubksb(double **a, int n, int *indx, double *b)
// Solves the set of n linear equations AX = B. Here a[1..n][1..n] is input, not as the matrix
// A but rather as its LU decomposition, determined by the routine ludcmp. indx[1..n] is input
// as the permutation vector returned by ludcmp. b[1..n] is input as the right-hand side vector
// B, and returns with the solution vector X. a, n, and indx are not modified by this routine
// and can be left in place for successive calls with different right-hand sides b. This routine takes
// into account the possibility that b will begin with many zero elements, so it is efficient for use
// in matrix inversion.
{
	int 	i;
	int 	ii=0;
	int	ip;
	int	j;
	double 	sum;

	for (i=1;i<=n;i++) 
	{ 	// When ii is set to a positive value, it will become the
		// index of the first nonvanishing element of b. We now
		// do the forward substitution, equation (2.3.6). The
		// only new wrinkle is to unscramble the permutation as we go.
		ip=indx[i];
		sum=b[ip];
		b[ip]=b[i];
		if (ii)
		{
			for (j=ii;j<=i-1;j++) 
				sum -= a[i][j]*b[j];
		}	
		else if (sum)
		{	
			ii=i; 	// A nonzero element was encountered, so from now on we
		}		// will have to do the sums in the loop above 
		b[i]=sum;
	}
	for (i=n;i>=1;i--) 
	{ 		// Now we do the backsubstitution, equation (2.3.7).
		sum=b[i];
		for (j=i+1;j<=n;j++) 
			sum -= a[i][j]*b[j];
		b[i]=sum/a[i][i]; 	// Store a component of the solution vector X.

	} // All done!
}


bool ludcmp(double **a, int n, int *indx, double *d)
// Given a matrix a[1..n][1..n], this routine replaces it by the LU decomposition of a rowwise
// permutation of itself. a and n are input. a is output, arranged as in equation (2.3.14) above;
// indx[1..n] is an output vector that records the row permutation effected by the partial
// pivoting; d is output as plus or minus one depending on whether the number of row interchanges was even
// or odd, respectively. This routine is used in combination with lubksb to solve linear equations
// or invert a matrix.
{
	int i,imax,j,k;
	double big,dum,sum,temp;
	double *vv;	// vv stores the implicit scaling of each row.
	
	vv = (double *)malloc( (n+1) * sizeof(double));	  // note NR code does no error checking inside routine
	if ( vv == NULL )
	{
		printf("Error allocating memory for matrix inverse. Exiting routine\n");
		return(false);
	}
	//vv=vector(1,n);
	
	*d=1.0; 	// No row interchanges yet.
	for (i=1;i<=n;i++) 
	{ 	// Loop over rows to get the implicit scaling informati
		big=0.0; 
		for (j=1;j<=n;j++)
		{
			if ((temp=fabs(a[i][j])) > big) 
				big=temp;
		}
		if (big == 0.0) 
		{
			printf("Warning: Singular matrix was encountered in routine ludcmp");
			return(false);
		}
		// No nonzero largest element.
		vv[i]=1.0/big; 	// Save the scaling.
	}
	for (j=1;j<=n;j++) 
	{ 	//This is the loop over columns of Crout's method.
		for (i=1;i<j;i++) 
		{ 		//This is equation (2.3.12) except for i = j.
			sum=a[i][j];
			for (k=1;k<i;k++) 
				sum -= a[i][k]*a[k][j];
			a[i][j]=sum;
		}
		big=0.0; 		// Initialize for the search for largest pivot element.
		for (i=j;i<=n;i++) 
		{ 			//This is i = j of equation (2.3.12) and i = j+1. . .N
			sum=a[i][j]; 	// of equation (2.3.13).
			for (k=1;k<j;k++)
				sum -= a[i][k]*a[k][j];
			a[i][j]=sum;
			if ( (dum=vv[i]*fabs(sum)) >= big) 
			{
				// Is the figure of merit for the pivot better than the best so far?
				big=dum;
				imax=i;
			}
		}
		if (j != imax) 
		{ 		// Do we need to interchange rows?
			for (k=1;k<=n;k++) 
			{ 	// Yes, do so...
				dum=a[imax][k];
				a[imax][k]=a[j][k];
				a[j][k]=dum;

			}
			*d = -(*d); 		// ...and change the parity of d.
			vv[imax]=vv[j]; 	// Also interchange the scale factor.

		}
		indx[j]=imax;
		if (a[j][j] == 0.0) 
			a[j][j]=TINY_NO;	// defined in vectorMath.h

		// If the pivot element is zero the matrix is singular (at least to the precision of the
		// algorithm). For some applications on singular matrices, it is desirable to substitute
		// TINY for zero.
		if (j != n) 
		{ 		//	Now, finally, divide by the pivot element.
			dum=1.0/(a[j][j]);
			for (i=j+1;i<=n;i++) 
				a[i][j] *= dum;

		}
	} // Go back for the next column in the reduction.

	//free_vector(vv,1,n);
	free(vv);

	return (true);
}


