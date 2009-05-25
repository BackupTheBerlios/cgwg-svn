#ifndef PAES_SCHEDULEARCHIVE_HPP
#define PAES_SCHEDULEARCHIVE_HPP 1

#include <common.hpp>
#include <schedule.hpp>
#include <vector>

namespace scheduler {
  class ScheduleArchive {
	public:
	  typedef std::tr1::shared_ptr<ScheduleArchive> Ptr;
	  ScheduleArchive(const size_t size, const size_t workload_size) : 
		_maxQueueTime(0.0), _minQueueTime(0.0),
		_maxPrice(0.0), _minPrice(0.0), _tainted(true), _maxSize(size), 
		_workload_size(workload_size), _population() {
		_archive=new std::vector<scheduler::Schedule::Ptr>;
	  };
	  virtual ~ScheduleArchive() {
		delete(_archive);
	  };
	  /**
	   * returns true if the schedule dominated to the archive,
	   */
	  bool archiveSchedule(const scheduler::Schedule::Ptr schedule);
	  const std::string getRelLogLines();
	  const std::string getAbsLogLines();
//	  const std::string str();
	  const size_t size() { return _archive->size(); };
	  const double getMaxQueueTime();
	  const double getMaxPrice();
	  const double getMinQueueTime();
	  const double getMinPrice();
	  /**
	   * Returns the distance of the Pareto front to the coordinate
	   * system.
	   */
	  const double getDistance();
	  void updateAllLocations();
	  /**
	   * Returns true if at least one schedule in the archive dominates
	   * the schedule parameter.
	   */
	  bool dominates(const scheduler::Schedule::Ptr& schedule);
	  /**
	   * Returns true if the schedule dominates all archived schedules.
	   */
	  bool isDominated(const scheduler::Schedule::Ptr& schedule);
	  std::string getPopulationStr();
	  const unsigned long getPopulationCount(scheduler::Schedule::LocationType location);

	private:
	  void updateMinMaxValues ();
	  void addSchedule(const scheduler::Schedule::Ptr schedule);
	  unsigned long getMaxPopulationCount();
	  scheduler::Schedule::LocationType encodeDimensions(
		  const scheduler::Schedule::LocationDimensionType& priceDimension,
		  const scheduler::Schedule::LocationDimensionType& queueTimeDimension);
	  scheduler::Schedule::LocationDimensionType calculateLocation(
		  const double& current, const double& min, const double& max);
	  ScheduleArchive (const ScheduleArchive& original);
	  ScheduleArchive& operator= (const ScheduleArchive& rhs);
	  std::vector<scheduler::Schedule::Ptr>* _archive;
	  double _maxQueueTime;
	  double _minQueueTime;
	  double _maxPrice;
	  double _minPrice;
	  bool _tainted;
	  size_t _maxSize;
	  size_t _workload_size;
	  std::map<std::string, unsigned long> _population;
  };
}

#endif /* PAES_SCHEDULEARCHIVE_HPP */

