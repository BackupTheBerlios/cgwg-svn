#ifndef PAES_SCHEDULEARCHIVE_HPP
#define PAES_SCHEDULEARCHIVE_HPP 1

#include <common.hpp>
#include <schedule.hpp>
#include <vector>

namespace scheduler {
  class ScheduleArchive {
	public:
	  typedef std::tr1::shared_ptr<ScheduleArchive> Ptr;
	  ScheduleArchive() : 
		_archive(), _maxQueueTime(0.0), _minQueueTime(0.0),
		_maxPrice(0.0), _minPrice(0.0), _tainted(true) {};
	  virtual ~ScheduleArchive() {};

	  void addSchedule(const scheduler::Schedule::Ptr schedule);
	  const std::string getLogLines();
	  const std::string str();
	  const double getMaxQueueTime();
	  const double getMaxPrice();
	  const double getMinQueueTime();
	  const double getMinPrice();
	  /**
	   * Returns true if at least one schedule in the archive dominates
	   * the schedule parameter.
	   */
	  bool dominates(const scheduler::Schedule::Ptr& schedule);

	private:
	  void updateMinMaxValues ();
	  ScheduleArchive (const ScheduleArchive& original);
	  ScheduleArchive& operator= (const ScheduleArchive& rhs);
	  std::vector<scheduler::Schedule::Ptr> _archive;
	  double _maxQueueTime;
	  double _minQueueTime;
	  double _maxPrice;
	  double _minPrice;
	  bool _tainted;
  };
}

#endif /* PAES_SCHEDULEARCHIVE_HPP */

