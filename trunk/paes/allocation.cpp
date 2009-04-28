#include "allocation.hpp"
#include <sstream>

using namespace scheduler;


const std::string Allocation::str() const {
  std::ostringstream oss;
  oss << "Allocation for JID: " << _jobID << " ST: " << _startTime;
  oss << " QT: " << _queueTime << " FT: "<< _finishTime << " P: " << _price;
  return oss.str();
}
