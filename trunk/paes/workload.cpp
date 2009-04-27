#include "workload.hpp"
#include <sstream>

using namespace scheduler;

const std::string Workload::str() {
  std::ostringstream oss;
  oss << "Workload of " << _jobs.size() <<" jobs:" << std::endl;
  JobIteratorType it;
  for (it=_jobs.begin(); it < _jobs.end(); it++) {
	oss << (*it)->str() << std::endl;
  }
  return oss.str();
}

void Workload::add(scheduler::Job::Ptr job) {
  _jobs.push_back(job);
}
