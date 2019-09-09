%module royale

%{
#define SWIG_FILE_WITH_INIT
#define ROYALE_NEW_API_3_1_0_0_0
#define ROYALE_FINAL_API_3_1_0_0_0

#include <DepthDataCAPI.h>
#include <DepthImageCAPI.h>
#include <CameraDeviceCAPI.h>
#include <CameraManagerCAPI.h>
%}

%include CustomAPI.i
