#ifndef PAES_WORKLOAD_HPP
#define PAES_WORKLOAD_HPP 1
#include <common.hpp>
#include <job.hpp>
#include <vector>

namespace scheduler	{
  class Workload {
	public:
	  typedef std::vector<scheduler::Job::Ptr>::iterator JobIteratorType;
	  typedef std::tr1::shared_ptr<Workload> Ptr;
	  Workload () : _jobs() {};
	  virtual ~Workload() {};
	  void add(scheduler::Job::Ptr job);
	  const std::string str() ;

	private:
	  Workload (const Workload& original);
	  Workload& operator= (const Workload& rhs);
	  std::vector<scheduler::Job::Ptr> _jobs;
	  
  };
}

#endif /* PAES_WORKLOAD_HPP */

