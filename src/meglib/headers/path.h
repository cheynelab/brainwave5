// Path seaparator definition for Linux/Mac/Windows


#ifndef PATH_H
#define PATH_H
#endif

#if defined _WIN64 || defined _WIN32
#define FILE_SEPARATOR "\\"
#define slash '\\'
#else
#define FILE_SEPARATOR "/"
#define slash '/'
#endif

