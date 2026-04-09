#ifndef	FILE_UTILS_H
#define	FILE_UTILS_H

//////////////////////////////////////////////////////////////////////////////
//                                                                          //
//                       FILE UTILS                                         //
//                                                                          //
//  File Utilities contains all of the extra methods dealing with           //
//  manipulation of file names.                                             //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////

void getFileParts( char *nameIn, char *pathOut, char *rootOut, char *extOut );

void getFilePath( char *nameIn, char *pathOut );

void removeFilePath( char *nameIn, char *nameOut );

void removeDotExtension( char *nameIn, char *nameOut );

// Purpose:  Gets the extension of the file name given in the parameter,
//	     nameIn.
// Parameters:  nameIn - file name
//	        extOut - the outputted extension (dot included)
//
void getDotExtension( char *nameIn, char *extOut );

// Purpose:  Prepends the absolute path of the output directory specified
//	     in the function's first argument to the file name specified
//	     in the function's second argument
// Parameters: dir - the absolute path of the directory to be prepended
//	       file - the file name for which the directory name will be prepended
//
bool prependPath( char *dir, char *file );



#endif





