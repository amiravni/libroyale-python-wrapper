#ifndef __ROYALE_WRAPPER_H__
#define __ROYALE_WRAPPER_H__

#include <royale/CameraManager.hpp>
#include <royale/Vector.hpp>
#include <royale/String.hpp>
#include <iostream>
#include <thread>
#include <chrono>

extern "C" {

  class MyListener : public royale::IDepthDataListener {
    void onNewData (const royale::DepthData *data) {
      /* Demonstration of how to retrieve exposureTimes
       * There might be different ExposureTimes per RawFrameSet resulting in a vector of
       * exposureTimes, while however the last one is fixed and purely provided for further
       * reference.
       */
      auto sampleVector (data->exposureTimes);

      if (sampleVector.size() > 0) {
	std::cout << "ExposureTimes #1: ";
	for (unsigned int i = 0; i < sampleVector.size(); ++i) {
	  std::cout << sampleVector.at (i);
	  if (i + 1 < sampleVector.size()) {
	    std::cout << ", ";
	  }
	}
	std::cout << std::endl;
      }

      // The data pointer will become invalid after onNewData returns.  When
      // processing the data, it's necessary to either:
      // 1. Do all the processing before this method returns, or
      // 2. Copy the data (not just the pointer) for later processing.
      //
      // The Royale library's depth-processing thread may block while waiting
      // for this function to return; if this function is slow then there
      // may be some lag between capture and onNewData for the next frame.
      // If it's very slow then Royale may drop frames to catch up.
    }
  };

  int test () {
    // this represents the main camera device object
    std::unique_ptr<royale::ICameraDevice> cameraDevice;
    // the camera manager will query for a connected camera
    {
      royale::CameraManager manager;

      auto camlist = manager.getConnectedCameraList();
      std::cout << "Detected " << camlist.size() << " camera(s)." << std::endl;
      if (!camlist.empty()) {
	std::cout << "CamID for first device: "
		  << camlist.at (0).c_str()
		  << " with a length of ("
		  << camlist.at (0).length()
		  << ")" << std::endl;
	cameraDevice = manager.createCamera (camlist[0]);
      }
    }
    // the camera device is now available and CameraManager can be deallocated here
    if (cameraDevice == nullptr) {
      std::cerr << "Cannot create the camera device" << std::endl;
      return 1;
    }
    // IMPORTANT: call the initialize method before working with the camera device
    if (cameraDevice->initialize() != royale::CameraStatus::SUCCESS) {
      std::cerr << "Cannot initialize the camera device" << std::endl;
      return 1;
    }
    royale::Vector<royale::String> useCases;
    auto status = cameraDevice->getUseCases (useCases);

    if (status != royale::CameraStatus::SUCCESS || useCases.empty())
    {
        std::cerr << "No use cases are available" << std::endl;
        std::cerr << "getUseCases() returned: " << getErrorString (status) << std::endl;
        return 1;
    }
    for (size_t i = 0; i < useCases.size(); ++i) {
      std::cout << useCases[i] << std::endl;
    }
    // register a data listener
    MyListener listener;
    if (cameraDevice->registerDataListener (&listener) != royale::CameraStatus::SUCCESS)
    {
      std::cerr << "Error registering data listener" << std::endl;
      return 1;
    }
    // set an operation mode
    if (cameraDevice->setUseCase (cameraDevice->getUseCases() [0]) != royale::CameraStatus::SUCCESS)
    {
        std::cerr << "Error setting use case" << std::endl;
        return 1;
    }
    // start capture mode
    if (cameraDevice->startCapture() != royale::CameraStatus::SUCCESS)
    {
        std::cerr << "Error starting the capturing" << std::endl;
        return 1;
    }
    // let the camera capture for some time
    std::this_thread::sleep_for (std::chrono::seconds (5));
    // change the exposure time (limited by the used operation mode [microseconds]
    if (cameraDevice->setExposureTime (200) != royale::CameraStatus::SUCCESS)
    {
        std::cerr << "Cannot set exposure time" << std::endl;
    }
    else
    {
      std::cout << "Changed exposure time to 200 microseconds ..." << std::endl;
    }
    // let the camera capture for some time
    std::this_thread::sleep_for (std::chrono::seconds (5));
    // stop capture mode
    if (cameraDevice->stopCapture() != royale::CameraStatus::SUCCESS)
    {
        std::cerr << "Error stopping the capturing" << std::endl;
        return 1;
    }
    return 0;
  };
}

#endif
