#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
//#include <iostream.h>
#include <math.h>
//#include <fstream.h>

#include "../headers/fileUtils.h"
#include "../headers/path.h"//File separator defined file, added by zhengkai

////////////////////////////////////////////////////////////////////////////
//                                                                        //
//                            FILE UTILS                                  //
//                                                                        //
// Contains methods dealing with manipulation of file names.  This project//
// was created to unify all of random file methods that existed in        //
// datasetUtils and surfaceUtils.                                         //
//                                                                        //
// By:  Tim Orr (tim@timorr.com)                                          //
//                                                                        //
////////////////////////////////////////////////////////////////////////////

// Revision History 
//
// version:	1.0 - initial check in
//

void getFileParts( char *nameIn, char *pathOut, char *rootOut, char *extOut )
{
	char	tempString[256];
	char    dot = '.';
	char	extString[256];
	char    *charPtr;

	getFilePath( nameIn, pathOut);
	removeFilePath( nameIn, tempString);
	removeDotExtension ( tempString, rootOut );

    charPtr = strrchr( nameIn, dot );
    if ( charPtr != NULL )
		strcpy( extOut, ++charPtr );
}

void removeDotExtension( char *nameIn, char *nameOut )
{
	char    *charPtr;
	char    dot = '.';
	char	extString[256];

	charPtr = strrchr( nameIn, dot );
	strcpy( nameOut, nameIn );

	// strrchr will return NULL if dot not found 
	// otherwise truncate input string by length of the extension (this includes the dot)
	if ( charPtr != NULL )
	{
		strcpy( extString, charPtr );
		int len = strlen(extString);
		nameOut[strlen(nameOut)-len] = '\0';
	}
}

// Purpose:  Gets the extension of the file name given in the parameter, nameIn.
// Parameters:  nameIn - file name
//		extOut - the outputted extension (dot included)
//
void getDotExtension( char *nameIn, char *extOut )
{
	char 	*charPtr;
	char	dot = '.';

	// finds last occurrence of the '.'
	charPtr = strrchr( nameIn, dot );

	// strrchr will return NULL if . not found
	// copy the result into extOut
	if ( charPtr != NULL )
	{
		strcpy( extOut, charPtr );
	}
}


void removeFilePath( char *nameIn, char *nameOut )
{
	char    *charPtr;
	//char    slash = '/';
	charPtr = strrchr( nameIn, slash );

	// strrchr will return NULL if slcsh not found (ie., no file path in name)
	if ( charPtr != NULL )
	{
		// incr. pointer to omit the slash and
		// check again to make sure it is still not null
		charPtr++;
		if ( charPtr != NULL )
			strcpy( nameOut, charPtr );
		else
			strcpy( nameOut, nameIn );
	}
	else
		strcpy( nameOut, nameIn );
}

void getFilePath( char *nameIn, char *pathOut )
{
        char    *charPtr;
        //char    slash = '/';

        strcpy( pathOut, nameIn );
        charPtr = strrchr( pathOut, slash );
        if ( charPtr != NULL )
            *(++charPtr) = '\0';
}

/////////////////////////////////////////////////////////////////////////////////////
// Method:  prependPath                                                            //
// Purpose: Prepends the absolute path of the directory specified in the function's//
//          first argument to the file name specified in the function's second     //
//	    argument.                                                              //
// Parameters:  dir - the absolute path of the directory to be prepended           //
//              file - the file name which has the directory name prepended        //
// Post-Condition:  The absolute path stored in dir will be prepended to file,     //
//		    and thus, the parameter 'file' will contain an absolute path   //
/////////////////////////////////////////////////////////////////////////////////////
bool prependPath( char *dir, char *file )
{
	char * slashPos;  // the position of the last "/" in the directory name
	int slashLen;  // the index position of the last "/" in the directory name
	int dirLen; // the number of characters of the directory name
	char newFile[2056] = "";  // placeholder to store the new file name

	// Find the position of the last slash.  If there are no slashes, chances
	// are that we have an incorrect directory name.
	//slashPos = strrchr( dir, '/' );
	slashPos = strrchr( dir, slash );
	if ( slashPos == NULL )
	{
		return false;
	}
	
	// Find the index position of the last "/"
	slashLen = int ( slashPos-dir+1 );

	// Find the length of the output directory name
	dirLen = int( strlen( dir ) );

	// If the last slash is not in the final position in the directory string, 
	// the user did not finish typing the directory name with a "/"
	// As such, we should add a "/" to the end of the directory name
	if ( slashLen != dirLen )
	{
		//strncat( dir, "/", 1 ); // add slash to end of directory name
		//strncat( dir, "/", 1 );
		strcat( dir, FILE_SEPARATOR );
	}

//    // Add the directory name to the newFile placeholder
//    strncat( newFile, dir, strlen(dir) );
//
//    // Add the file name to the newFile placeholder
//    strncat( newFile, file, strlen(file) );
    
    // Add the directory name to the newFile placeholder
    strcat( newFile, dir );
    
    // Add the file name to the newFile placeholder
    strcat( newFile, file );
	// Copy the entire directory name from the newFile placeholder to the
	// file name passed into this method
	strcpy( file, newFile );

	return true;
}



