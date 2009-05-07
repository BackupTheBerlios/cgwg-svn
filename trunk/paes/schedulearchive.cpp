#include "schedulearchive.hpp"
#include <sstream>
#include <float.h>


using namespace scheduler;


void ScheduleArchive::addSchedule(const scheduler::Schedule::Ptr schedule) {
  _archive.push_back(schedule);
  _tainted=true;
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

void ScheduleArchive::updateMinMaxValues () {
  if (_tainted) {
	_maxQueueTime = _maxPrice = 0.0;
	_minQueueTime = _minPrice = DBL_MAX;
	std::vector<scheduler::Schedule::Ptr>::iterator it;
	for(  it = _archive.begin(); it < _archive.end(); it++) {
	  // Do comparisons.
	  double qt=(*it)->getTotalQueueTime();
	  double p=(*it)->getTotalPrice();
	  if (qt > _maxQueueTime) _maxQueueTime = qt;
	  if (qt < _minQueueTime) _minQueueTime = qt;
	  if (p > _maxPrice) _maxPrice = p;
	  if (p < _minPrice) _minPrice = p;
	}
	_tainted=false;
  }
}


const double ScheduleArchive::getMaxQueueTime() {
  if (_tainted)
	updateMinMaxValues();
  return _maxQueueTime;
}

const double ScheduleArchive::getMaxPrice() {
  if (_tainted)
	updateMinMaxValues();
  return _maxPrice;
}

const double ScheduleArchive::getMinQueueTime() {
  if (_tainted)
	updateMinMaxValues();
  return _minQueueTime;
}

const double ScheduleArchive::getMinPrice() {
  if (_tainted)
	updateMinMaxValues();
  return _minPrice;
}

const std::string ScheduleArchive::str() {
  if (_tainted)
	updateMinMaxValues();
  std::ostringstream oss;
  oss << "ScheduleArchive contains " << _archive.size() << " schedules." << std::endl;
  oss << " - QT (min/max): "<< _minQueueTime << "/" << _maxQueueTime << std::endl;
  oss << " - Price (min/max): " << _minPrice << "/" << _maxPrice << std::endl;
  if (_tainted)
	oss << " - tainted." << std::endl;
  else
	oss << " - not tainted." << std::endl;
  return oss.str();
}
