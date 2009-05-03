#ifndef PRICINGPLAN_HPP
#define PRICINGPLAN_HPP 1

#include <common.hpp>
#include <job.hpp>


namespace scheduler {
  class PricingPlan {
	public:
	  typedef std::tr1::shared_ptr<PricingPlan> Ptr;
	  PricingPlan () {};
	  virtual ~PricingPlan() {};

	  virtual double getPrice(scheduler::Job::Ptr job) = 0;
	  virtual const std::string str() = 0;
	  
	private:
	  PricingPlan (const PricingPlan& original);
	  PricingPlan& operator= (const PricingPlan& rhs);

  };
}


#endif /* PRICINGPLAN_HPP */

