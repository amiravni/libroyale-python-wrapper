%{
#define SWIG_FILE_WITH_INIT
%}

%module royale

%define
ROYALE_NEW_API_2_2_0
ROYALE_FINAL_API_2_2_0
%enddef

%rename(DepthData) royale_depth_data;
%rename(DepthImage) royale_depth_image;
%include <DefinitionsCAPI.h>
%include <DepthDataCAPI.h>
%include <DepthImageCAPI.h>
%include <CameraDeviceCAPI.h>
%include <CameraManagerCAPI.h>
%include CustomAPI.i
