#ifndef PAES_SIMPLERESOURCE_HPP
#define PAES_SIMPLERESOURCE_HPP 1

#include <common.hpp>
#include <workload.hpp>
#include <resource.hpp>
#include <job.hpp>
#include <allocation.hpp>

namespace scheduler {
  class SimpleResource : public scheduler::Resource {
	public:
	  typedef std::tr1::shared_ptr<SimpleResource> Ptr;
	  typedef unsigned int IDType;
	  SimpleResource (IDType resourceID, const std::string& resourceName): 
			Resource (resourceID, resourceName), _jobs(), _allocations(),
			_totalQueueTime(0.0), _totalPrice(0.0) {};
	  virtual ~SimpleResource() {};

	  const std::string str();
	  void addJob(const scheduler::Job::Ptr& job);
	  void removeAllJobs();
	  void reSchedule();
	  bool sanityCheck();
	  const double getTotalQueueTime() { return _totalQueueTime; };
	  const double getTotalPrice() { return _totalPrice; };

	private:
	  SimpleResource (const SimpleResource& original);
	  SimpleResource& operator= (const SimpleResource& rhs);
	  std::map<scheduler::Job::IDType, scheduler::Job::Ptr> _jobs;
	  std::map<scheduler::Job::IDType, scheduler::Allocation::Ptr> _allocations;
	  double _totalQueueTime;
	  double _totalPrice;
  };
}

#endif /* PAES_SIMPLERESOURCE_HPP */

