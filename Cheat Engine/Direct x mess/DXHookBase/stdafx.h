// stdafx.h : include file for standard system include files,
// or project specific include files that are used frequently, but
// are changed infrequently
//

#pragma once

#include "targetver.h"

#define WIN32_LEAN_AND_MEAN             // Exclude rarely-used stuff from Windows headers
// Windows Header Files:
#include <windows.h>
#include <stdio.h>



#include <d3d9.h>
#include <d3d11.h>
#include <d3dx11.h>
#include <d3dcompiler.h>
#include "..\d3dhookshared.h"
#include "DXHookBase.h"

// Backward-compat: DXSDK (June 2010) lacks 11_1 feature level
#ifndef D3D_FEATURE_LEVEL_11_1
#define D3D_FEATURE_LEVEL_11_1 ((D3D_FEATURE_LEVEL)0xb100)
#endif



// TODO: reference additional headers your program requires here
