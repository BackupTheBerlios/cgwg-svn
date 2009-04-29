#ifndef PAES_RESOURCEPOOL_HPP
#define PAES_RESOURCEPOOL_HPP 1

#include <common.hpp>
#include <resource.hpp>
#include <map>
#include <vector>

namespace scheduler {
  class ResourcePool {
	public:
	  typedef std::tr1::shared_ptr<ResourcePool> Ptr;
	  typedef std::map<scheduler::Resource::IDType, scheduler::Resource::Ptr>::iterator ResourceIteratorType;
	  ResourcePool() : 
		_resources(), 
		_minResourceID(scheduler::Resource::RESOURCEID_MAX),
		_maxResourceID(0) {};
	  virtual ~ResourcePool() {};
	  void add(const scheduler::Resource::Ptr resource);
	  scheduler::Resource::IDType getRandomResourceID();
	  scheduler::Resource::Ptr getResourceByID(const scheduler::Resource::IDType& id);
	  std::vector<scheduler::Resource::Ptr> getAllResources();
	  const std::string str();
	  const size_t size() { return _resources.size(); };
	  bool sanityCheck();

	private:
	  ResourcePool (const ResourcePool& original);
	  ResourcePool& operator= (const ResourcePool& rhs);
	  std::map<scheduler::Resource::IDType, scheduler::Resource::Ptr> _resources;
	  scheduler::Resource::IDType _minResourceID;
	  scheduler::Resource::IDType _maxResourceID;
  };
}

#endif /* PAES_RESOURCEPOOL_HPP */

