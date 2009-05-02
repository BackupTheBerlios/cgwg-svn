#ifndef PAES_SCHEDULE_HPP
#define PAES_SCHEDULE_HPP 1
#include <common.hpp>
#include <vector>
#include <simpleresource.hpp>
#include <resourcepool.hpp>
#include <workload.hpp>


namespace scheduler {
  class Schedule {
	public:
	  typedef std::tr1::shared_ptr<Schedule> Ptr;
	  typedef std::pair<scheduler::Job::IDType, scheduler::SimpleResource::IDType> SchedulePairType;
	  Schedule (const scheduler::Workload::Ptr& workload, const scheduler::ResourcePool::Ptr& resources);
	  Schedule (const Schedule& original); 
	  virtual ~Schedule() {};
	  const std::string str();
	  const std::string getAllocationTable();
	  void randomSchedule();
	  void mutate();
	  void propagateJobsToResources();
	  void processSchedule();
	  void removeAllJobs();
	  const double getTotalQueueTime();
	  const double getTotalPrice();

	private:
	  Schedule& operator= (const Schedule& rhs);
	  scheduler::Workload::Ptr _workload;
	  scheduler::ResourcePool::Ptr _resources;
	  std::vector<SchedulePairType> _schedule;
	  bool _tainted;
	  double _totalQueueTime;
	  double _totalPrice;
  };

}


#endif /* PAES_SCHEDULE_HPP */

