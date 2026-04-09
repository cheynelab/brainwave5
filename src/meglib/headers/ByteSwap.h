#ifndef BYTESWAP_H
#define BYTESWAP_H

//added TCP/IP API package for windows, added by zhengkai
#if defined _WIN64 || defined _WIN32
    #include<stdint.h> //For windows, C99 package added
	#include <winsock2.h>//For MinGw, network API package.
    #include <winsock.h>
    #include <windows.h>
#else
	#include <netinet/in.h>
#endif


// * D. Cheyne July, 2007 -  replaced __bswap32  __bswap64 from netinet with this code in case they can't be found (e.g., MacIntel)
// ** works on Xeon Mac -- needs testing on Linux platforms ? 

#define bswap_32(x) \
({ \
	uint32_t __x = (x); \
		((uint32_t)( \
					 (((uint32_t)(__x) & (uint32_t)0x000000ffUL) << 24) | \
					 (((uint32_t)(__x) & (uint32_t)0x0000ff00UL) <<  8) | \
					 (((uint32_t)(__x) & (uint32_t)0x00ff0000UL) >>  8) | \
					 (((uint32_t)(__x) & (uint32_t)0xff000000UL) >> 24) )); \
})

#define bswap_64(x) \
({ \
	uint64_t __x = (x); \
		((uint64_t)( \
					 (uint64_t)(((uint64_t)(__x) & (uint64_t)0x00000000000000ffULL) << 56) | \
					 (uint64_t)(((uint64_t)(__x) & (uint64_t)0x000000000000ff00ULL) << 40) | \
					 (uint64_t)(((uint64_t)(__x) & (uint64_t)0x0000000000ff0000ULL) << 24) | \
					 (uint64_t)(((uint64_t)(__x) & (uint64_t)0x00000000ff000000ULL) <<  8) | \
					 (uint64_t)(((uint64_t)(__x) & (uint64_t)0x000000ff00000000ULL) >>  8) | \
					 (uint64_t)(((uint64_t)(__x) & (uint64_t)0x0000ff0000000000ULL) >> 24) | \
					 (uint64_t)(((uint64_t)(__x) & (uint64_t)0x00ff000000000000ULL) >> 40) | \
					 (uint64_t)(((uint64_t)(__x) & (uint64_t)0xff00000000000000ULL) >> 56) )); \
})

enum { HOST_TO_NETWORK = 0, NETWORK_TO_HOST };

inline const short ToHost( const short parm )
{
	return ntohs( parm );
}
inline const short ToFile( const short parm )
{
	return htons( parm );
}
inline const int ToHost( const int parm )
{
	return ntohl( parm );
}
inline const int ToFile( const int parm )
{
	return htonl( parm );
}
inline const long ToHost( const long parm )
{
	return ntohl( parm );
}
inline const long ToFile( const long parm )
{
	return htonl( parm );
}

#ifdef __ppc__ 
	inline const float ToFile( const float parm )
	{
		return(parm);
	}
	inline const float ToHost( const float parm )
	{
		return(parm);
	}

	inline const double ToFile( const double parm )
	{
		return(parm);
	}
	inline const double ToHost( const double parm )	
	{
		return(parm);
	}
#else
	inline const float ToFile( const float parm )
	{
		long* ll = ( ( long*)(&parm) );
		*ll = bswap_32(  *ll );
		return *( ( float *)ll );
	}
	inline const float ToHost( const float parm )
	{
		return ToFile( parm );
	}

	inline const double ToFile( const double parm )
	{
		long long* ll = ( (long  long*)(&parm) );
		*ll =  bswap_64( *ll );
		return *( ( double *)ll );
	}
	inline const double ToHost( const double parm )	
	{
		return ToFile( parm );
	}
#endif

#endif

