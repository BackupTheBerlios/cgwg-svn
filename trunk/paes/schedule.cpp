#include "schedule.hpp"
#include <random.hpp>
#include <sstream>
#include <utility>


using namespace scheduler;

Schedule::Schedule (const scheduler::Workload::Ptr& workload,
	const scheduler::ResourcePool::Ptr& resources) : 
  _workload(workload),  
  _resources(resources),  
  _schedule(), 
  _tainted(true),
  _totalQueueTime(0.0),
  _totalPrice(0.0)
{ }

/**
 * Copy constructor - copies the exact state of the current schedule,
 * assigns jobs to the resources.
 */
Schedule::Schedule (const Schedule& original) :
  _workload(original._workload),  
  _resources(original._resources),  
  _schedule(original._schedule),
  _tainted(original._tainted),
  _totalQueueTime(original._totalQueueTime),
  _totalPrice(original._totalPrice)
{
  //propagateJobsToResources();
  //_tainted=false;
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

/**
 * Mutates the current schedule by assigning a random job to a different
 * resource.
 */
void Schedule::mutate() {
  util::RNG& rng=util::RNG::instance();
  size_t jobIndex = rng.uniform_derivate_ranged_int(0, _schedule.size()-1);
  scheduler::Resource::IDType oldResourceID=_schedule[jobIndex].second;
  scheduler::Resource::IDType newResourceID;
  do {
	newResourceID=_resources->getRandomResourceID();
  } while (newResourceID == oldResourceID);
  //std::cout << "Jobindex " << jobIndex << ": Swapping resource " << oldResourceID << " to " << newResourceID << std::endl;
  _schedule[jobIndex].second = newResourceID;
  //TODO: Do this only for the old and new resource - the others are not tainted.
  propagateJobsToResources();
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
  removeAllJobs();
  std::vector<Schedule::SchedulePairType>::iterator it;
  for(  it = _schedule.begin(); it < _schedule.end(); it++) {
	scheduler::Job::IDType jobID=(*it).first;
	scheduler::Job::Ptr job=_workload->getJobByID(jobID);
	scheduler::Resource::IDType resourceID=(*it).second;
	scheduler::Resource::Ptr resource = _resources->getResourceByID(resourceID);
	resource->addJob(job);
  }
  _tainted=true;
}

scheduler::Schedule::DOMINATION Schedule::compare(const Schedule::Ptr& other) {
  if (_tainted) {
	// update the resources
	update();
  }
  if (_totalPrice < other->getTotalPrice()) {
	if (_totalQueueTime < other->getTotalQueueTime()) {
	  return DOMINATES; // we dominate other
	} else {
	  return NO_DOMINATION; // no one dominates the other
	}
  } else { // _totalPrice >= other.getTotalPrice()
	if (_totalQueueTime >= other->getTotalQueueTime()) {
	  return IS_DOMINATED; // the other dominates us
	} else {
	  return NO_DOMINATION; // no one dominates the other
	}
  }
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
  _totalQueueTime=_totalPrice=0.0;
  std::vector<scheduler::Resource::Ptr> resourceList = _resources->getAllResources();
  std::vector<scheduler::Resource::Ptr>::iterator it; 
  for(  it = resourceList.begin(); it < resourceList.end(); it++) {
	if ((*it)->isTainted()) {
	  (*it)->reSchedule();
	}
	_totalQueueTime += (*it)->getTotalQueueTime();
	_totalPrice += (*it)->getTotalPrice();
  }
  _tainted=false;
}

void Schedule::update() {
  propagateJobsToResources();
  processSchedule();
}

const double Schedule::getTotalQueueTime() {
  if (_tainted) {
	// update the resources
	update();
  }
  return _totalQueueTime;
}

const double Schedule::getTotalPrice() {
  if (_tainted) {
	// update the resources
	update();
  }
  return _totalPrice;
}
