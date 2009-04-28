#ifndef PAES_SIMPLERESOURCE_HPP
#define PAES_SIMPLERESOURCE_HPP 1

#include <common.hpp>
#include <workload.hpp>
#include <resource.hpp>
#include <job.hpp>

namespace scheduler {
  class SimpleResource : public scheduler::Resource {
	public:
	  typedef std::tr1::shared_ptr<SimpleResource> Ptr;
	  typedef unsigned int IDType;
	  SimpleResource (IDType resourceID, const std::string& resourceName): 
			Resource (resourceID, resourceName), _jobs() {};
	  virtual ~SimpleResource() {};

	  const std::string str();
	  void addJob(const scheduler::Job::Ptr& job);
	  void reSchedule();

	private:
	  SimpleResource (const SimpleResource& original);
	  SimpleResource& operator= (const SimpleResource& rhs);
	  std::map<scheduler::Job::IDType, scheduler::Job::Ptr> _jobs;
  };
}

#endif /* PAES_SIMPLERESOURCE_HPP */

