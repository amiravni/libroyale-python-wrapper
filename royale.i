%{
#define SWIG_FILE_WITH_INIT
%}

%module royale

%define
ROYALE_NEW_API_2_2_0
ROYALE_FINAL_API_2_2_0
%enddef

%include DefinitionsCAPI.h
%rename(DepthData) royale_depth_data;
%include DepthDataCAPI.h
%rename(DepthImage) royale_depth_image;
%include DepthImageCAPI.h
%include CameraDeviceCAPI.h
%include CameraManagerCAPI.h
%include CustomAPI.i
