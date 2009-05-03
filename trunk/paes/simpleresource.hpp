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
	  SimpleResource (IDType resourceID, const std::string& resourceName, scheduler::PricingPlan::Ptr pricingPlan): 
			Resource (resourceID, resourceName, pricingPlan), _jobs(), _allocations() {};
	  SimpleResource (const SimpleResource& original);
	  virtual ~SimpleResource() {};

	  const std::string str();
	  void addJob(const scheduler::Job::Ptr& job);
	  void removeAllJobs();
	  void reSchedule();
	  bool sanityCheck();
	  void clear();

	  const double getTotalQueueTime();
	  const double getTotalPrice(); 

	private:
	  SimpleResource& operator= (const SimpleResource& rhs);
	  std::map<scheduler::Job::IDType, scheduler::Job::Ptr> _jobs;
	  std::map<scheduler::Job::IDType, scheduler::Allocation::Ptr> _allocations;
  };
}

#endif /* PAES_SIMPLERESOURCE_HPP */

