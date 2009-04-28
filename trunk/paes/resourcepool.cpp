#include "resourcepool.hpp"
#include <random.hpp>
#include <sstream>

using namespace scheduler;

void ResourcePool::add(const scheduler::Resource::Ptr resource) {
  Resource::IDType currentID(resource->getResourceID());
  _resources[currentID]=resource;
  if (currentID < _minResourceID) 
	_minResourceID = currentID;
  if (currentID > _maxResourceID)
	_maxResourceID = currentID;
}

scheduler::Resource::Ptr ResourcePool::getResourceByID(const scheduler::Resource::IDType& id) {
  Resource::Ptr retval(_resources[id]);
  return retval;
}

scheduler::Resource::IDType ResourcePool::getRandomResourceID() {
  util::RNG& rng=util::RNG::instance();
  return rng.uniform_derivate_ranged_int(_minResourceID, _maxResourceID);
}

std::vector<scheduler::Resource::Ptr> ResourcePool::getAllResources() {
  std::vector<scheduler::Resource::Ptr> retval;
  ResourceIteratorType it;
  for (it=_resources.begin(); it != _resources.end(); it++) {
	retval.push_back((*it).second);
  }
  return retval;
}

const std::string ResourcePool::str() {
  std::ostringstream oss;
  oss << "Resourcepool of " << _resources.size() <<" resources:"; 
  ResourceIteratorType it;
  for (it=_resources.begin(); it != _resources.end(); it++) {
	oss << std::endl << (*it).second->str();
  }
  return oss.str();
}
