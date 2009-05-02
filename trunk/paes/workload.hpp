#ifndef PAES_WORKLOAD_HPP
#define PAES_WORKLOAD_HPP 1
#include <common.hpp>
#include <job.hpp>
#include <map>
#include <vector>

namespace scheduler	{
  class Workload {
	public:
	  typedef std::map<scheduler::Job::IDType, scheduler::Job::Ptr>::iterator JobIteratorType;
	  typedef std::tr1::shared_ptr<Workload> Ptr;
	  Workload () : _jobs() {};
	  virtual ~Workload() {};
	  void add(scheduler::Job::Ptr job);
	  const scheduler::Job::IDType getMinJobID();
	  const scheduler::Job::IDType getMaxJobID();
	  const scheduler::Job::IDType getRandomJobID();
	  std::vector<scheduler::Job::IDType> getJobIDs();
	  const size_t size() { return _jobs.size(); };
	  const std::string str();

	  scheduler::Job::Ptr getJobByID(const scheduler::Job::IDType& id);

	private:
	  Workload (const Workload& original);
	  Workload& operator= (const Workload& rhs);
	  std::map<scheduler::Job::IDType, scheduler::Job::Ptr> _jobs;
	  
  };
}

#endif /* PAES_WORKLOAD_HPP */

