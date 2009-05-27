#include <config.hpp>
#include <sstream>
#include <pricingplan.hpp>
#include <linearpricing.hpp>
#include <simpleresource.hpp>

using namespace config;

const std::string config::getConfigString() {
  std::ostringstream oss;
  oss << "Configuration id: " << config::CONFIG_NAME;
  oss << ", Location size: " << config::LOCATION_DIMENSION_SIZE;
  oss << ", Archive size: " << config::ARCHIVE_SIZE;
  oss << ", Max iterations: " << config::MAX_ITERATION;
  return oss.str();
}
  
scheduler::ResourcePool::Ptr config::createResourcePool() {
  if (CONFIG_NAME == THREE_SIMPLE_RESOURCES)
	return create3SimpleResources();
  else {
	std::ostringstream oss;
	oss << "Config id " << CONFIG_NAME << ": no such configuration available.";
	throw std::runtime_error(oss.str());
  }
}

scheduler::ResourcePool::Ptr config::create3SimpleResources() {
  scheduler::ResourcePool::Ptr resources(new scheduler::ResourcePool());
  std::cout << "Creating 3 simple resources." << std::endl;
  for(unsigned int i=0; i<3; i++) {
	std::ostringstream oss;
	oss << "Resource-" << i;
	scheduler::PricingPlan::Ptr simplePricing(new scheduler::LinearPricing(0.1*(i+1)));
	scheduler::SimpleResource::Ptr resource(new scheduler::SimpleResource(i, oss.str(), simplePricing));
	resources->add(resource);
  }
  return resources;
}
