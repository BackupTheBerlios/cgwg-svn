#ifndef PAES_SCHEDULE_HPP
#define PAES_SCHEDULE_HPP 1
#include <common.hpp>
#include <config.hpp>
#include <vector>
#include <bitset>
#include <simpleresource.hpp>
#include <resourcepool.hpp>
#include <workload.hpp>


namespace scheduler {
  class Schedule {
	public:
	  enum DOMINATION {
		DOMINATES, IS_DOMINATED, NO_DOMINATION
	  } my_Domination;
	  typedef std::tr1::shared_ptr<Schedule> Ptr;
	  typedef std::pair<scheduler::Job::IDType, scheduler::SimpleResource::IDType> SchedulePairType;
	  typedef std::bitset<config::NUM_LOCATION_BITS> LocationType;
	  typedef std::bitset<config::LOCATION_DIMENSION_SIZE> LocationDimensionType;
	  Schedule (const scheduler::Workload::Ptr& workload, const scheduler::ResourcePool::Ptr& resources);
	  Schedule (const Schedule& original); 
	  virtual ~Schedule() {};
	  const std::string str();
	  const std::string getAllocationTable();
	  void randomSchedule();
	  /**
	   * Compares this schedule to another one.
	   * returns 
	   *	DOMINATES if this one dominates the other
	   *	IS_DOMINATED if other dominates this one
	   *	NO_DOMINATION otherwise.
	   */
	  DOMINATION compare(const Schedule::Ptr& other);
	  bool dominates(const Schedule::Ptr& other);
	  bool equals(const Schedule::Ptr& other);
	  void mutate();
	  void update();
	  void removeAllJobs();
	  const double getTotalQueueTime();
	  const double getTotalPrice();
	  const bool isTainted() { return _tainted; };
	  LocationType getLocation() { return _location; };
	  void setLocation(LocationType location) { _location=location; };

	private:
	  void propagateJobsToResources();
	  void processSchedule();
	  Schedule& operator= (const Schedule& rhs);
	  scheduler::Workload::Ptr _workload;
	  scheduler::ResourcePool::Ptr _resources;
	  std::vector<SchedulePairType> _schedule;
	  LocationType _location;
	  bool _tainted;
	  double _totalQueueTime;
	  double _totalPrice;
  };

}


#endif /* PAES_SCHEDULE_HPP */

