#include "schedule.hpp"
#include <sstream>
#include <utility>


using namespace scheduler;

/**
 * Copy constructor - copies the exact state of the current schedule,
 * assigns jobs to the resources.
 */
Schedule::Schedule (const Schedule& original) :
		_workload(original._workload),  
		_resources(original._resources),  
		_schedule(original._schedule) {
  propagateJobsToResources();
  _tainted=false;
}

void Schedule::randomSchedule() {
  std::vector<scheduler::Job::IDType> jobIDs = _workload->getJobIDs();
  std::vector<scheduler::Job::IDType>::iterator it;
  for(  it = jobIDs.begin(); it < jobIDs.end(); it++) {
	scheduler::Resource::IDType resourceID=_resources->getRandomResourceID();
	SchedulePairType allocation=std::make_pair((*it), resourceID);
	_schedule.push_back(allocation);
  }
  _tainted=true;
}

const std::string Schedule::str() {
  std::ostringstream oss;
  oss << "Schedule: " << _workload->size() << " jobs, "<< _resources->size() << " resources.";
  if (_tainted)
	oss << " (tainted)";
  else
	oss << " (not tainted)";
  return oss.str();
}

const std::string Schedule::getAllocationTable() {
  std::ostringstream oss;
  oss << "current allocations: " << _workload->size() << " jobs, "<< _resources->size() << " resources." << std::endl;
  oss << "job id\tresource id" << std::endl;
  std::vector<SchedulePairType>::iterator it;
  for(  it = _schedule.begin(); it < _schedule.end(); it++) {
	scheduler::Job::IDType jobID=(*it).first;
	scheduler::Resource::IDType resourceID=(*it).second;
	oss << jobID << "\t" << resourceID << std::endl;
  }
  return oss.str();
}

void Schedule::propagateJobsToResources() {
  std::vector<Schedule::SchedulePairType>::iterator it;
  for(  it = _schedule.begin(); it < _schedule.end(); it++) {
	scheduler::Job::IDType jobID=(*it).first;
	scheduler::Job::Ptr job=_workload->getJobByID(jobID);
	scheduler::Resource::IDType resourceID=(*it).second;
	scheduler::Resource::Ptr resource = _resources->getResourceByID(resourceID);
	resource->addJob(job);
  }
  _tainted=false;
}

void Schedule::removeAllJobs() {
  std::vector<scheduler::Resource::Ptr> resourceList = _resources->getAllResources();
  std::vector<scheduler::Resource::Ptr>::iterator it; 
  for(  it = resourceList.begin(); it < resourceList.end(); it++) {
	(*it)->removeAllJobs();
  }
  _tainted=true;
}

void Schedule::processSchedule() {
  std::vector<scheduler::Resource::Ptr> resourceList = _resources->getAllResources();
  std::vector<scheduler::Resource::Ptr>::iterator it; 
  for(  it = resourceList.begin(); it < resourceList.end(); it++) {
	(*it)->reSchedule();
  }
}


const double Schedule::getTotalQueueTime() {
  double retval=0.0;
  std::vector<scheduler::Resource::Ptr> resourceList = _resources->getAllResources();
  std::vector<scheduler::Resource::Ptr>::iterator it; 
  for(  it = resourceList.begin(); it < resourceList.end(); it++) {
	if ((*it)->isTainted()) {
	  (*it)->reSchedule();
	}
	retval += (*it)->getTotalQueueTime();
  }
  return retval;
}

const double Schedule::getTotalPrice() {
  double retval=0.0;
  std::vector<scheduler::Resource::Ptr> resourceList = _resources->getAllResources();
  std::vector<scheduler::Resource::Ptr>::iterator it; 
  for(  it = resourceList.begin(); it < resourceList.end(); it++) {
	if ((*it)->isTainted()) {
	  (*it)->reSchedule();
	}
	retval += (*it)->getTotalPrice();
  }
  return retval;
}
