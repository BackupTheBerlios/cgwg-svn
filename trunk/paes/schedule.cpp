#include "schedule.hpp"
#include <sstream>
#include <utility>


using namespace scheduler;

void Schedule::randomSchedule() {
  std::vector<scheduler::Job::IDType> jobIDs = _workload->getJobIDs();
  std::vector<scheduler::Job::IDType>::iterator it;
  for(  it = jobIDs.begin(); it < jobIDs.end(); it++) {
	scheduler::Resource::IDType resourceID=_resources->getRandomResourceID();
	SchedulePairType allocation=std::make_pair((*it), resourceID);
	_schedule.push_back(allocation);
  }
}

// void propagateSchedule -> puts jobs on the resources

// double queueTime -> collects information from the resources
// double price -> collects information from the resources

const std::string Schedule::str() {
  std::ostringstream oss;
  oss << "Schedule: " << _workload->size() << " jobs, "<< _resources->size() << " resources.";
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
}

void Schedule::removeAllJobs() {
  std::vector<scheduler::Resource::Ptr> resourceList = _resources->getAllResources();
  std::vector<scheduler::Resource::Ptr>::iterator it; 
  for(  it = resourceList.begin(); it < resourceList.end(); it++) {
	(*it)->removeAllJobs();
  }
}

void Schedule::processSchedule() {
  std::vector<scheduler::Resource::Ptr> resourceList = _resources->getAllResources();
  std::vector<scheduler::Resource::Ptr>::iterator it; 
  for(  it = resourceList.begin(); it < resourceList.end(); it++) {
	(*it)->reSchedule();
  }
}

