#include "schedulearchive.hpp"
#include <sstream>

using namespace scheduler;


void ScheduleArchive::addSchedule(const scheduler::Schedule::Ptr schedule) {
  _archive.push_back(schedule);
}

const std::string ScheduleArchive::getLogLines() {
  std::ostringstream oss;
  oss << "QT\tPrice" << std::endl;
  std::vector<scheduler::Schedule::Ptr>::iterator it;
  for(  it = _archive.begin(); it < _archive.end(); it++) {
	oss << (*it)->getTotalQueueTime() << "\t";
	oss << (*it)->getTotalPrice() << std::endl;
  }
  return oss.str();
}

bool ScheduleArchive::dominates(const scheduler::Schedule::Ptr& schedule) {
  std::vector<scheduler::Schedule::Ptr>::iterator it;
  for(  it = _archive.begin(); it < _archive.end(); it++) {
	if ((*it)->compare(schedule) == scheduler::Schedule::DOMINATES)
	  return true;
  }
  return false;
}
const std::string ScheduleArchive::str() {
  std::ostringstream oss;
  oss << "ScheduleArchive contains " << _archive.size() << " schedules.";
  return oss.str();
}
