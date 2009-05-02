#include "workload.hpp"
#include <random.hpp>
#include <sstream>

using namespace scheduler;

const std::string Workload::str() {
  std::ostringstream oss;
  oss << "Workload of " << _jobs.size() <<" jobs:" << std::endl;
  JobIteratorType it;
  for (it=_jobs.begin(); it != _jobs.end(); it++) {
	oss << (*it).second->str() << std::endl;
  }
  return oss.str();
}

void Workload::add(scheduler::Job::Ptr job) {
  Job::IDType currentID(job->getJobID());
  _jobs[currentID]=job;
  //if (currentID < _minResourceID) 
  //  _minResourceID = currentID;
  //if (currentID > _maxResourceID)
  //  _maxResourceID = currentID;

  //_jobs.push_back(job);
}

// TODO: Implement caching of the value
const scheduler::Job::IDType Workload::getMinJobID() {
  scheduler::Job::IDType retval = scheduler::Job::JOBID_MAX;
  JobIteratorType it;
  for (it=_jobs.begin(); it != _jobs.end(); it++) {
	if ((*it).second->getJobID() < retval)
	  retval=((*it).second->getJobID());
  }
  return retval;
}

// TODO: Implement caching of the value
const scheduler::Job::IDType Workload::getMaxJobID() {
  scheduler::Job::IDType retval = 0;
  JobIteratorType it;
  for (it=_jobs.begin(); it != _jobs.end(); it++) {
	if ((*it).second->getJobID() > retval)
	  retval=((*it).second->getJobID());
  }
  return retval;
}

const scheduler::Job::IDType Workload::getRandomJobID() {
  util::RNG& rng=util::RNG::instance();
  return rng.uniform_derivate_ranged_int(getMinJobID(), getMaxJobID());
}
 
scheduler::Job::Ptr Workload::getJobByID(const scheduler::Job::IDType& id) {
  Job::Ptr retval(_jobs[id]);
  return retval;
}

std::vector<scheduler::Job::IDType> Workload::getJobIDs() {
  std::vector<scheduler::Job::IDType> retval;
  JobIteratorType it;
  for (it=_jobs.begin(); it != _jobs.end(); it++) {
	retval.push_back((*it).second->getJobID());
  }
  return retval;
}
