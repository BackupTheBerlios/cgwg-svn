#include "schedulearchive.hpp"
#include <sstream>

using namespace scheduler;


void ScheduleArchive::addSchedule(const scheduler::Schedule::Ptr schedule) {
  _archive.push_back(schedule);
}


const std::string ScheduleArchive::str() {
  std::ostringstream oss;
  oss << "ScheduleArchive contains " << _archive.size() << " schedules.";
  return oss.str();
}
