#ifndef PAES_RESOUCE_HPP
#define PAES_RESOUCE_HPP 1

#include <common.hpp>
#include <job.hpp>
#include <pricingplan.hpp>

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
	  Resource (IDType resourceID, const std::string& resourceName, 
		  scheduler::PricingPlan::Ptr pricingPlan) :  
		_resourceID(resourceID), _resourceName(resourceName), _tainted(true),
		_totalQueueTime(0.0), _totalPrice(0.0), _pricingPlan(pricingPlan) {}; 
	  Resource (const Resource& original) :
		_resourceID(original.getResourceID()), 
		_resourceName(original.getResourceName()), 
		_tainted(original._tainted),
		_totalQueueTime(original._totalQueueTime), 
		_totalPrice(original._totalPrice),
		_pricingPlan(original._pricingPlan) {}; 
	  virtual ~Resource() {};
	  virtual const std::string str() = 0;
	  const IDType getResourceID() const { return _resourceID; };
	  const std::string getResourceName() const { return _resourceName; };
	  const bool isTainted() { return _tainted; };

	  virtual void addJob(const scheduler::Job::Ptr& job) = 0;
	  virtual void reSchedule()=0;
	  virtual bool sanityCheck() =0;
	  virtual void removeAllJobs()=0;
	  virtual const double getTotalQueueTime()=0;
	  virtual const double getTotalPrice()=0; 


	private:
	  Resource& operator= (const Resource& rhs);
	  IDType _resourceID;
	  std::string _resourceName;
	protected:
	  bool _tainted;
	  double _totalQueueTime;
	  double _totalPrice;
	  scheduler::PricingPlan::Ptr _pricingPlan;
  };

}

#endif /* PAES_RESOUCE_HPP */

