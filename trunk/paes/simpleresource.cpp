#include "simpleresource.hpp"
#include <sstream>


using namespace scheduler;

const std::string SimpleResource::str() {
  std::ostringstream oss;
  oss << "Simple resource " << getResourceName() << "(id: " << getResourceID() << ")";
  oss << ", " << _jobs.size() << " jobs";
  oss << " total QT: " << _totalQueueTime << ", total price: " << _totalPrice;
  return oss.str();
}

// TODO: mark the current state as tainted...
void SimpleResource::addJob(const scheduler::Job::Ptr& job) {
  Job::IDType currentID(job->getJobID());
  _jobs[currentID]=job;
}

void SimpleResource::removeAllJobs() {
  _jobs.clear();
  _allocations.clear();
  _totalQueueTime = _totalPrice = 0.0;
}

//TODO: The schedule can be built more efficiently during addJob.
void SimpleResource::reSchedule() {
  std::cout << "Rescheduling " << getResourceName() << std::endl;
  // The jobs are sorted by the map, so we get increasing job ids automatically.
  double freetime=0.0;
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
	price=1.0;
	_totalPrice += price;
	freetime=starttime + current->getRunTime();
	// Create a new allocation for this job
	Allocation::Ptr allocation(new Allocation(current->getJobID(), starttime, queuetime, finishtime, price));
	//std::cout << "generated "<< allocation->str() << std::endl;
	_allocations[currentID]=allocation;
  }
}

