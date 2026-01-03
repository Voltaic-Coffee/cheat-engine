#pragma once

// Minimal precompiled header for shared Common C++ code.
// Kept intentionally small: only widely used Windows/CRT headers.

#ifdef _WINDOWS
#include <windows.h>
#include <stdio.h>
#endif

// Add other common includes here if Common/*.cpp files start
// depending on them project-wide.
