#include "simpleresource.hpp"
#include <sstream>


using namespace scheduler;

const std::string SimpleResource::str() {
  std::ostringstream oss;
  oss << "Simple resource " << getResourceName() << "(id: " << getResourceID() << ")";
  oss << ", " << _jobs.size() << " jobs";
  return oss.str();
}

void SimpleResource::addJob(const scheduler::Job::Ptr& job) {
  Job::IDType currentID(job->getJobID());
  _jobs[currentID]=job;
}

//TODO: The schedule can be built more efficiently during addJob.
void SimpleResource::reSchedule() {
  std::cout << "Rescheduling " << getResourceName() << std::endl;
  // 1. Sort jobs according to their submission time
  // 2. Calculate the allocation times
  
}
