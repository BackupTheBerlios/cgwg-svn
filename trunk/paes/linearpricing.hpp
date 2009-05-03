#ifndef LINEARPRICING_HPP
#define LINEARPRICING_HPP 1

#include <common.hpp>
#include <pricingplan.hpp>
#include <sstream>


namespace scheduler {
  class LinearPricing : public PricingPlan {
	public:
	  typedef std::tr1::shared_ptr<LinearPricing> Ptr;
	  LinearPricing (const double basePrice) : _basePrice(basePrice) {};
	  virtual ~LinearPricing() {};

	  double getPrice(scheduler::Job::Ptr job) {
		return (_basePrice * job->getRunTime());
	  }

	  const std::string str() {
		std::ostringstream oss;
		oss << "Linear pricing plan: baseprice=" << _basePrice;
		return oss.str();
	  }

	private:
	  LinearPricing (const LinearPricing& original);
	  LinearPricing& operator= (const LinearPricing& rhs);
	  double _basePrice;
  };
  
}

#endif /* LINEARPRICING_HPP */

