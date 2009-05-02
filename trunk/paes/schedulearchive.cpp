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
	scheduler::Schedule::Ptr current=(*it);
	oss << current->getTotalQueueTime() << "\t";
	oss << current->getTotalPrice() << std::endl;
  }
  return oss.str();
}

const std::string ScheduleArchive::str() {
  std::ostringstream oss;
  oss << "ScheduleArchive contains " << _archive.size() << " schedules.";
  return oss.str();
}
