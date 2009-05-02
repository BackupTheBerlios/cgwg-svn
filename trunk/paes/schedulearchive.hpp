#ifndef PAES_SCHEDULEARCHIVE_HPP
#define PAES_SCHEDULEARCHIVE_HPP 1

#include <common.hpp>
#include <schedule.hpp>
#include <vector>

namespace scheduler {
  class ScheduleArchive {
	public:
	  typedef std::tr1::shared_ptr<ScheduleArchive> Ptr;
	  ScheduleArchive() : _archive() {};
	  virtual ~ScheduleArchive() {};

	  void addSchedule(const scheduler::Schedule::Ptr schedule);
	  const std::string getLogLines();
	  const std::string str();

	private:
	  ScheduleArchive (const ScheduleArchive& original);
	  ScheduleArchive& operator= (const ScheduleArchive& rhs);
	  std::vector<scheduler::Schedule::Ptr> _archive;
  };
}

#endif /* PAES_SCHEDULEARCHIVE_HPP */

