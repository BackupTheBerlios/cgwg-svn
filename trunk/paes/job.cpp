#include "job.hpp"

using namespace scheduler;
	  
const std::string Job::str() const {
  std::ostringstream oss;
  oss << "JID " << _jobid << ", submit " << _submit_time << ", run ";
  oss << _run_time << ", wall " << _wall_time << ", size " << _size;
  return oss.str();
}

