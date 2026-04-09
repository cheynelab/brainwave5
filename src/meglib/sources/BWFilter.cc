/* document version history
1.2	- code beautifying
1.3	- testing build_filter coefficients (wip)
   From old meg4 lib
*/

#include <stdio.h>
#include "../headers/BWFilter.h"
#include "../headers/complex_math.h"

int	build_filter ( filter_params	*fp	)
{
	COMPLEX			znpoly[P];
	COMPLEX			zdpoly[P];
	COMPLEX			numrut[P];
	COMPLEX			denrut[P];
	COMPLEX			zpole[P];
	COMPLEX			zzero[P];
	COMPLEX			root[P];
	COMPLEX			cgain;
	COMPLEX			btmp;
	COMPLEX			dtmp;
	double			psi;
	double			arg;
	double			gain;
	double			wo;
	double			wh;
	double			wc;
	double			tmp;
	int				order;
	int				even;
	int				npole;
	int				nzero;
	int				i;
	int				j;


	if (!fp->enable)
	{
		return ( -1 );   // should not be called if filter is disabled ...
	}
	
	if ( fp->order < 1 || fp->order > MAXORDER)
	{
		return ( -1 );
	}

	// check that cutoff is below nyquist
	//
	if ( fp->type ==  BW_LOWPASS || fp->type ==  BW_BANDPASS )
	{
		if ( fp->hc > ( 0.5 * fp->fs ) )
			return (-1);	
	}
	
	// set number of coefficients
	switch(fp->type)
	{
		case BW_HIGHPASS:
		case BW_LOWPASS:
			fp->ncoeff = fp->order + 1;
			break;
		case BW_BANDPASS:
		case BW_BANDREJECT:
			fp->ncoeff = 2 * fp->order + 1;
			break;
		default:
			return -1;
	}

	// initialize polynomials
	for(i=1; i<P; i++)
		znpoly[i] = zdpoly[i] = COMPLEX_ZERO;

	// compute location of Butterworth poles from filter order
	even = (fp->order / 2) * 2;
	psi = M_PI / (double)fp->order;
	arg = (even == fp->order) ? .5 * psi : psi;
	for(i=1; i<=even; i+=2) {
		denrut[i] = Cset(-cos(arg), sin(arg));
		denrut[i+1] = Conj(denrut[i]);
		arg += psi;
	}
	if(even != fp->order)
		denrut[fp->order] = COMPLEX_MONE;
	npole = fp->order;

	// map frequency to warped z-plane frequency
	tmp = M_PI / fp->fs;		// conversion factor for frequency to radians/sec
	wo = tan((double)(fp->lc * tmp));
	wh = tan((double)(fp->hc * tmp));

	// compute location of Butterworth zeroes from filter type
	switch(fp->type) 
	{
		case BW_LOWPASS:
			nzero = 0;
			for(i=1, gain=1.; i<=npole; i++) 
			{
				denrut[i] = Cscale(wh, denrut[i]);
				gain *= wh;	/* gain = wh^npole */
			}
			break;

		case BW_HIGHPASS:
			nzero = npole;
			for(i=1; i<=nzero; i++) 
			{
				numrut[i] = COMPLEX_ZERO;
				denrut[i] = Cdiv(Cset(wo, 0.), denrut[i]);
			}
			gain = 1.;
			break;

		case BW_BANDPASS:
			nzero = npole;
			wc = wo * wh;
			wh -= wo;
			for(i=1, gain=1.; i<=npole; i++) 
			{
				numrut[i] = COMPLEX_ZERO;
				gain *= wh;	/* gain = wh^npole */
			}
			for(i=1, j=1; i<=npole; i++, j+=2) 
			{
				btmp = Cscale(-wh, denrut[i]);
				dtmp = Csqrt(Csub(Cmul(btmp, btmp), Cset(4. * wc, 0.)));
				root[j] = Cscale(.5, Csub(dtmp, btmp));
				root[j+1] = Cscale(.5, Csub(Csub(COMPLEX_ZERO, dtmp), btmp));
			}
			npole *= 2;
			for(i=1; i<=npole; i++)
				denrut[i] = root[i];
			break;

		case BW_BANDREJECT:
			gain = 1.;
			wc = wo * wh;
			wh -= wo;
			for(i=1, j=1; i<=npole; i++, j+=2) 
			{
				numrut[j] = Cset(0., sqrt(wc));
				numrut[j+1] = Conj(numrut[j]);
				btmp = Csqrt(Csub(Cset(wh*wh, 0.), Cscale(4.*wc, Cmul(denrut[i], denrut[i]))));
				dtmp = Cscale(2., denrut[i]);
				root[j] = Cdiv(Cadd(Cset(wh, 0.), btmp), dtmp);
				root[j+1] = Cdiv(Csub(Cset(wh, 0.), btmp), dtmp);
			}
			npole *= 2;
			nzero = npole;
			for(i=1; i<=npole; i++)
				denrut[i] = root[i];
			break;

		default:
			return -1;
	}

	// map poles & zeroes from s to z-plane
	cgain = Cset(gain, 0.);
	for(i=1; i<=nzero; i++) 
	{
		zpole[i] = Bilin(denrut[i]);
		zzero[i] = Bilin(numrut[i]);
		cgain = Cmul(cgain, Cdiv(Csub(COMPLEX_ONE, numrut[i]), Csub(COMPLEX_ONE, denrut[i])));
	}

	// map any zeroes at +/- infinity to (-1, 0)
	if(npole > nzero) 
	{
		for(i=(nzero+1); i<=npole; i++) 
		{
			zzero[i] = COMPLEX_MONE;
			zpole[i] = Bilin(denrut[i]);
			cgain = Cdiv(cgain, Csub(COMPLEX_ONE, denrut[i]));
		}
		nzero = npole; 
	}
	cgain = Cmul(cgain, Conj(cgain));
	gain = sqrt(cgain.r);

	// multiply out all sections to form numerator & denominator polynomial
	znpoly[1] = COMPLEX_ONE;			
	zdpoly[1] = COMPLEX_ONE;
	znpoly[2] = Csub(COMPLEX_ZERO, zzero[1]);	
	zdpoly[2] = Csub(COMPLEX_ZERO, zpole[1]);
	for(j=2, order=1; j<=npole; j++, order++) 
	{
		for(i=(order+2); i>=2; i--) 
		{
			znpoly[i] = Csub(znpoly[i], Cmul(zzero[j], znpoly[i-1]));
			zdpoly[i] = Csub(zdpoly[i], Cmul(zpole[j], zdpoly[i-1]));
		}
	}

	// multiply numerator by gain
	for(i=1; i<=(nzero+1); i++)
		znpoly[i] = Cscale(gain, znpoly[i]);

	// output real part of complex polynomial as numerator & denominator coefficients
	for(i=1; i<=(npole+1); i++) 
	{
		fp->num[i-1] = znpoly[i].r;
		fp->den[i-1] = zdpoly[i].r;
	}

	FILTER_INITIALIZED = TRUE;

	return 0;
	
}

int	applyFilter ( double *in, double *out, int npts, filter_params *fp )
{
	static double	*tmp;		// temporary time-series
	double			offset;		// value of 0th data point
	double			temp;
	int				mo;			// coefficient limits
	int				t;			// time-index
	int				i;			// coefficient-index
	double			*iPtr;
	double			*oPtr;
	double			*tPtr;
	double			*nPtr;
	double			*dPtr;
	double			*inPtr;
	double			*outPtr;
	double			*tmpPtr;
	static int		mem = 0;

	if ( !FILTER_INITIALIZED )
		return -1;

	if (mem != npts) 
	{
		if ( mem != 0)
			delete [] tmp;
		if ( (tmp = new double[npts]) == 0)
			return -1;
		mem = npts;
	}

	// ** remove DC offset before filtering
	//
	double dcOffset;
	inPtr = in;
	dcOffset = 0.0;
	for ( t=0; t<npts; t++ ) 
		dcOffset += (*inPtr++);
	dcOffset /= (double)npts;
	inPtr = in;
	for ( t=0; t<npts; t++ ) 
		(*inPtr++) -= dcOffset;
	
	tmpPtr = tmp;
	inPtr = in;
	fp->den[0] = 0.;		// set 1st term of denominator to zero
	offset = *inPtr;			// get starting value to offset series
	for(t=0; t<fp->ncoeff; t++, tmpPtr++, inPtr++) 
	{
		iPtr = inPtr;
		tPtr = tmpPtr;
		temp = *tPtr = 0.0;
		nPtr = fp->num;
		dPtr = fp->den;
		for(i=t+1; --i >= 0;)
			temp += (*nPtr++) * ((*iPtr--) - offset) - (*dPtr++) * (*tPtr--);
		*tmpPtr = temp;
	}
	for(t=fp->ncoeff; t<npts; t++, tmpPtr++, inPtr++) 
	{
		iPtr = inPtr;
		tPtr = tmpPtr;
		temp = *tPtr = 0.0;
		nPtr = fp->num;
		dPtr = fp->den;
		for(i=fp->ncoeff; --i >= 0;)
			temp += (*nPtr++) * ((*iPtr--) - offset) - (*dPtr++) * (*tPtr--);
		*tmpPtr = temp;
	}

	// results are in tmp, move to out unless doing reverse filtering
	//
	if ( !fp->bidirectional )
	{
		outPtr = out;
		tmpPtr = tmp;
		for ( t=0; t<npts; t++ ) 
			*outPtr++ = *tmpPtr++;
		return 0;
	}

	// filter in reverse direction...
	tmpPtr = &tmp[npts-1];
	outPtr = &out[npts-1];
	offset = *tmpPtr;	// get ending value to offset series
	for(t=(npts-1); t>=npts-fp->ncoeff; t--, tmpPtr--, outPtr--) 
	{
		mo = npts-t;
		oPtr = outPtr;
		tPtr = tmpPtr;
		temp = *oPtr = 0.0;
		nPtr = fp->num;
		dPtr = fp->den;
		for(i=mo; --i >= 0;)
			temp += (*nPtr++) * ((*tPtr++) - offset) - (*dPtr++) * (*oPtr++);
		*outPtr = temp;
	}
	for(t=(npts-fp->ncoeff-1); t>=0; t--, tmpPtr--, outPtr--) 
	{
		oPtr = outPtr;
		tPtr = tmpPtr;
		temp = *oPtr = 0.0;
		nPtr = fp->num;
		dPtr = fp->den;
		for(i=fp->ncoeff; --i >= 0;)
			temp += (*nPtr++) * ((*tPtr++) - offset) - (*dPtr++) * (*oPtr++);
		*outPtr = temp;
	}
	return 0;
}


//int main_old()
//{
//	double num[MAXORDER];
//	double den[MAXORDER];
//
//	double dataIn[625];
//	double dataOut[625];
//	char buffer[20];
//
//        char string[81];
//	FILE *handle;
//
//	int i = 0;
//	
//
//	// Read the inputdata into the input matrix
//	handle=fopen("inputdata.txt", "r");
//	if(!handle)
//	{
//		puts("error opening file inputdata.txt\n");
//		return 1;
//	}
//
//	for (int i = 0; i <= 624; i++)
//	{
//		fgets(buffer, 15, handle);
//		buffer[15] = '\0';
//		dataIn[i] = atof(buffer);
//		printf("Buffer: %s\n", buffer);
//		printf("Float Data: %f\n", dataIn[i]);
//	}
//
//	fclose(handle);	
//
//
//	// Set dataOut to initial values
//	for (int i = 0; i <= 624; i++)
//	{
//		dataOut[i] = 0;
//	}
//	
//	
//	//  Test the LOWPASS Butterworth Filter
///*	filter_params fparam= {BW_LOWPASS, TRUE, 90, 0, 625, 4, 0, num[0], den[0]};
//	build_filter(&fparams);
//	applyFilter(dataIn, dataOut, 625, &fparams); */
//
//
//	// Test the HIGHPASS Butterworth Filter
///*	filter_params fparams = {BW_HIGHPASS, TRUE, 0, 90, 625, 4, 0, num[0], den[0]};
//	build_filter(&fparams);
//	applyFilter(dataIn, dataOut, 625, &fparams); */
//	
//	// Test the BANDPASS filter
///*	filter_params fparams = {BW_BANDPASS, TRUE, 90, 10, 625, 8, 0, num[0], den[0]};
//	build_filter(&fparams);
//	applyFilter(dataIn, dataOut, 625, &fparams); */
//
//	// Test the BANDREJECT filter
//	filter_params fparams = {BW_BANDREJECT, TRUE, 90, 10, 625, 8, 0, num[0], den[0]};
//	build_filter(&fparams);
//	applyFilter(dataIn, dataOut, 625, &fparams);
//
//	
//	// Dump the filtered data into a text file
//	handle=fopen("outputdata.txt","w");
//	if(!handle)
//	{
//		puts("Error opening file outputdata.txt\n");
//	        return 1;
//	}
//
//	//fprintf(handle, "------------------------------------------ INPUT DATA ------------------------ \n ");
//        //for (int i = 0; i <= 624; i++)
//	//{ 
//	//	fprintf(handle, "%f ", dataIn[i]);
//	//}
//	
//	//fprintf(handle, "\n\n\n\n\n\n\n");	
//
//	//fprintf(handle, "------------------------------------------ OUTPUT DATA ----------------------- \n ");
//	for (int i = 0; i <= 624; i++)
//	{
//		fprintf(handle, "%f\n", dataOut[i]);
//	}
//
//	fprintf(handle, "\n\n");
//
//	fclose(handle);
//	return 0;
//}
