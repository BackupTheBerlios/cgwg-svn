#ifndef PAES_RESOUCE_HPP
#define PAES_RESOUCE_HPP 1

#include <common.hpp>
#include <job.hpp>

namespace scheduler {
 // class Job;
/**
 * Interface for all resources.
 */
  class Resource {
	public:
	  typedef std::tr1::shared_ptr<Resource> Ptr;
	  typedef unsigned int IDType;
	  static const IDType RESOURCEID_MAX = UINT_MAX;
	  Resource (IDType resourceID, const std::string& resourceName) :  
		_resourceID(resourceID), _resourceName(resourceName) {}; //, _workload(workload){};
			//const scheduler::Workload::Ptr workload) = 0;
	  virtual ~Resource() {};
	  virtual const std::string str() = 0;
	  const IDType getResourceID() const { return _resourceID; };
	  const std::string getResourceName() const { return _resourceName; };

	  virtual void addJob(const scheduler::Job::Ptr& job) = 0;
	  virtual void reSchedule()=0;
	  virtual bool sanityCheck() =0;
	  virtual void removeAllJobs()=0;


	private:
	  Resource (const Resource& original);
	  Resource& operator= (const Resource& rhs);
	  IDType _resourceID;
	  std::string _resourceName;

  };

}

#endif /* PAES_RESOUCE_HPP */

