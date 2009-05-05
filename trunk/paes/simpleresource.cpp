#include "simpleresource.hpp"
#include <sstream>
#include <taintedstateexception.hpp>

using namespace scheduler;

SimpleResource::SimpleResource (const SimpleResource& original) : 
  Resource (original), 
  _jobs(original._jobs), 
  _allocations(original._allocations)
{ }

const std::string SimpleResource::str() {
  std::ostringstream oss;
  oss << "# Simple resource " << getResourceName() << "(id: " << getResourceID() << ")";
  oss << ", " << _jobs.size() << " jobs";
  oss << " total QT: " << _totalQueueTime << ", total price: " << _totalPrice;
  if (_tainted)
	oss << ", tainted, ";
  else
	oss << ", not tainted, ";
  oss << _pricingPlan->str();
  return oss.str();
}

void SimpleResource::addJob(const scheduler::Job::Ptr& job) {
  Job::IDType currentID(job->getJobID());
  _jobs[currentID]=job;
  _tainted=true;
}

void SimpleResource::removeAllJobs() {
  _jobs.clear();
  clear();
}

void SimpleResource::clear() {
  _allocations.clear();
  _totalQueueTime = _totalPrice = 0.0;
  _tainted=false;
}

//TODO: The schedule can be built more efficiently during addJob.
void SimpleResource::reSchedule() {
  //std::cout << "Rescheduling " << getResourceName() << std::endl;
  // The jobs are sorted by the map, so we get increasing job ids automatically.
  double freetime=0.0;
  _totalQueueTime = _totalPrice = 0.0;
  // 2. Calculate the allocation times
  std::map<scheduler::Job::IDType, scheduler::Job::Ptr>::iterator it;
  for (it=_jobs.begin(); it != _jobs.end(); it++) {
	Job::Ptr current=(*it).second;
	Job::IDType currentID(current->getJobID());
	double starttime, queuetime, finishtime, price= 0.0;
	if (freetime < current->getSubmitTime()) {
	  // the job can run instantly.
	  starttime=current->getSubmitTime();
	} else { // (freetime >= job.submitTime)
	  // The job must wait for the resource to become available.
	  starttime = freetime;
	}
	queuetime = starttime - current->getSubmitTime();
	_totalQueueTime += queuetime;
	finishtime = starttime + current->getRunTime();
	price=_pricingPlan->getPrice(current);
	_totalPrice += price;
	freetime=starttime + current->getRunTime();
	// Create a new allocation for this job
	Allocation::Ptr allocation(new Allocation(current->getJobID(), starttime, queuetime, finishtime, price));
	//std::cout << "generated "<< allocation->str() << std::endl;
	_allocations[currentID]=allocation;
  }
  _tainted=false;
}

bool SimpleResource::sanityCheck() {
    bool success=true;
    if (_allocations.size() >= 2) {
	  std::map<scheduler::Job::IDType, scheduler::Allocation::Ptr>::iterator it;
	  it=_allocations.begin();
	  scheduler::Allocation::Ptr precursor=(*it).second;
	  for (it=(++it); it != _allocations.end(); it++) {
		scheduler::Allocation::Ptr current=(*it).second;
		//std::cout << "Precursor: " << precursor->str() << ", current " << current->str() << std::endl;
		if (current->getStartTime() < _jobs[(*it).first]->getSubmitTime()) {
		  std::cout << "Start time before submit time!" << std::endl;
		  std::cout << "Precursor: " << precursor->str() << ", current " << current->str() << std::endl;
		  success=false;
		}
		if (current->getStartTime() < precursor->getFinishTime()) {
		  std::cout << "Start time before previous job finish time!" << std::endl;
		  std::cout << "Precursor: " << precursor->str() << ", current " << current->str() << std::endl;
		  success=false;
		}
		if (_jobs[(*it).first]->getSubmitTime() < _jobs[precursor->getJobID()]->getSubmitTime()) {
		  std::cout << "submit time before previous submit time!" << std::endl;
		  std::cout << "Precursor: " << precursor->str() << ", current " << current->str() << std::endl;
		  success=false;
		}
		precursor=current;
	  }
	}	
	if (success)
	  std::cout << "Simple Resource "<< getResourceName() <<": Sanity check successful." << std::endl;
	else
	  std::cout << "Simple Resource "<< getResourceName() << ": Sanity FAIL" << std::endl;
	return success;
}

const double SimpleResource::getTotalQueueTime() {
  if (! _tainted)
	return _totalQueueTime;
  else
	throw TaintedStateException("Tainted: No up-to-date total QT available.");
}

const double SimpleResource::getTotalPrice() {
  if (! _tainted)
	return _totalPrice;
  else
	throw TaintedStateException("Tainted: No up-to-date total price available.");
}
