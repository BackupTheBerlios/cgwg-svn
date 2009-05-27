#include "schedulearchive.hpp"
#include <sstream>
#include <algorithm>
#include <float.h>
#include <cmath>
#include <taintedstateexception.hpp>
#include <random.hpp>


using namespace scheduler;


void ScheduleArchive::addSchedule(const scheduler::Schedule::Ptr schedule) {
  _archive->push_back(schedule);
  _tainted=true;
}

bool ScheduleArchive::archiveSchedule(const scheduler::Schedule::Ptr schedule) {
  bool retval=false;
  bool foundDominated=false;
  // Check if the new schedule is a duplicate - ignore it.
  std::vector<scheduler::Schedule::Ptr>::iterator it;
  for(  it = _archive->begin(); it < _archive->end(); it++) {
	if ((*it)->equals(schedule)) {
	  //std::cout << "*** Attempt to add duplicate schedule to archive, ignoring " << schedule->str() << std::endl;
	  return false;
	}
  }
  if (_archive->size() == 0) { // If archive is empty: add and exit.
	addSchedule(schedule);
  } else {
	//std::cout << "*** Assessing schedule." << std::endl;
	// Check if the new solution dominates any of the archived solutions.
	std::vector<scheduler::Schedule::Ptr>* newArchive=new std::vector<scheduler::Schedule::Ptr>();
	std::vector<scheduler::Schedule::Ptr>::iterator it;
	for(  it = _archive->begin(); it < _archive->end(); it++) {
	  if (schedule->dominates((*it))) {
		//std::cout << "*** Found dominated schedule: " << (*it)->str() << std::endl;
		foundDominated=true;
	  } else {
		newArchive->push_back((*it));
	  }
	}
	if (foundDominated) {
	  //std::cout << "*** Swapping the archives." << std::endl;
	  // Swap the vectors.
	  delete(_archive);
	  _archive=newArchive;
	  // The new schedule dominated at least one solution - add it to the archive.
	  addSchedule(schedule);
	} else {
	  // no archived solution was dominated by the new one - free memory.
	  //std::cout << "*** No archived solution was dominated by the new one." << std::endl;
	  delete(newArchive);
	  // The current schedule is non-dominated by the list, but doesn't dominate other schedules.
	  if (_archive->size() < _maxSize) {
		// There's still space left, store this one.
		addSchedule(schedule);
	  } else {
		// Compare locations & replace a solution from the most crowded space.
		//std::cout << "*** Using location pressure to replace an existing solution." << std::endl;
		unsigned long maxPopulation=getMaxPopulationCount();
		std::vector<unsigned long> removeCandidates;
		retval=true;
		std::vector<scheduler::Schedule::Ptr>::iterator it;
		unsigned long currentIndex = 0;
		for(  it = _archive->begin(); it != _archive->end(); it++) {
		  scheduler::Schedule::LocationType location=(*it)->getLocation();
		  unsigned long population=getPopulationCount(location);
		  if (population == maxPopulation)
			removeCandidates.push_back(currentIndex);
		  ++currentIndex;
		}
		// Select a schedule to replace
		util::RNG& rng=util::RNG::instance();
		unsigned long replaceIndex=rng.uniform_derivate_ranged_int(0, removeCandidates.size()-1);
		assert(replaceIndex < removeCandidates.size());
		//std::cout << "Replacing candidate no. " << removeCandidates[replaceIndex] << std::endl;
		_archive->erase(_archive->begin() + removeCandidates[replaceIndex]);
		//for(it = _archive->begin(); it != _archive->end();) {
		//  scheduler::Schedule::LocationType location=(*it)->getLocation();
		//  unsigned long population=getPopulationCount(location);
		//  if (population == maxPopulation) {
		//	it = _archive->erase(it);
		//	break;
		//  } else
		//	++it;
		//}

		//std::cout << "*** replacing " << (*replace)->str() << ", max population: " << maxPopulation << std::endl;
		//_archive->erase(replace);
		addSchedule(schedule);
	  }
	}
  }
  //return retval;
  return foundDominated;
}

unsigned long ScheduleArchive::getMaxPopulationCount() {
  unsigned long maxPopulation=0;
  std::vector<scheduler::Schedule::Ptr>::iterator it;
  for(  it = _archive->begin(); it < _archive->end(); it++) {
	scheduler::Schedule::LocationType location=(*it)->getLocation();
	unsigned long population=getPopulationCount(location);
	if (population > maxPopulation) {
	  maxPopulation = population;
	}
  }
  return maxPopulation;
}

bool sortSchedulePredicate(const scheduler::Schedule::Ptr a, const scheduler::Schedule::Ptr b) {
  if ((a->getTotalQueueTime()) < (b->getTotalQueueTime())) {
	return true;
  } else if ((a->getTotalQueueTime()) == (b->getTotalQueueTime())) {
	return ((a->getTotalPrice()) < (b->getTotalPrice()));
  } else {
	return false;
  }
}

const double ScheduleArchive::getDistance() {
  double total_area=0.0;
  double prev_price=getMinPrice();
  double prev_qt=getMinQueueTime();
  std::sort(_archive->begin(), _archive->end(), sortSchedulePredicate);
  std::vector<scheduler::Schedule::Ptr>::iterator it;
  for(  it = _archive->begin(); it < _archive->end(); it++) {
	double deltaPrice=fabs(prev_price - (*it)->getTotalPrice());
	double deltaQT= fabs(((*it)->getTotalQueueTime() - prev_qt));
	total_area += ((deltaQT * (*it)->getTotalPrice()) + (deltaQT * (deltaPrice/2)));
	prev_qt=(*it)->getTotalQueueTime();
	prev_price=(*it)->getTotalPrice();
  }
  return total_area;
}

const std::string ScheduleArchive::getRelLogLines() {
  std::sort(_archive->begin(), _archive->end(), sortSchedulePredicate);
  std::ostringstream oss;
  oss << "QT\tPrice" << std::endl;
  std::vector<scheduler::Schedule::Ptr>::iterator it;
  for(  it = _archive->begin(); it < _archive->end(); it++) {
	oss << ((*it)->getTotalQueueTime()/_workload_size) << "\t";
	oss << ((*it)->getTotalPrice()/_workload_size) << std::endl;
  }
  return oss.str();
}

const std::string ScheduleArchive::getAbsLogLines() {
  std::sort(_archive->begin(), _archive->end(), sortSchedulePredicate);
  std::ostringstream oss;
  oss << "QT\tPrice" << std::endl;
  std::vector<scheduler::Schedule::Ptr>::iterator it;
  for(  it = _archive->begin(); it < _archive->end(); it++) {
	oss << (*it)->getTotalQueueTime() << "\t";
	oss << (*it)->getTotalPrice() << std::endl;
  }
  return oss.str();
}

bool ScheduleArchive::dominates(const scheduler::Schedule::Ptr& schedule) {
  std::vector<scheduler::Schedule::Ptr>::iterator it;
  for(  it = _archive->begin(); it < _archive->end(); it++) {
	if ((*it)->compare(schedule) == scheduler::Schedule::DOMINATES)
	  return true;
  }
  return false;
}

bool ScheduleArchive::isDominated(const scheduler::Schedule::Ptr& schedule) {
  std::vector<scheduler::Schedule::Ptr>::iterator it;
  for(it = _archive->begin(); it < _archive->end(); it++) {
	if ((*it)->dominates(schedule))
	  return false;
  }
  return true;
}

void ScheduleArchive::updateMinMaxValues () {
  if (_tainted) {
	_maxQueueTime = _maxPrice = 0.0;
	_minQueueTime = _minPrice = DBL_MAX;
	std::vector<scheduler::Schedule::Ptr>::iterator it;
	for(  it = _archive->begin(); it < _archive->end(); it++) {
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

scheduler::Schedule::LocationDimensionType ScheduleArchive::calculateLocation(
	const double& current, const double& min, const double& max) {
  if ((current < min) || (current > max)) 
	throw TaintedStateException("Tainted: current value is not in the [min; max]-Interval.");
  double lBound = min;
  double uBound = max;
  scheduler::Schedule::LocationDimensionType location;
  for( unsigned int i = 0; i < config::LOCATION_DIMENSION_SIZE; i += 1) {
	location <<= 1;
	double center=lBound + ((uBound - lBound) / 2.0);
	//	std::cout << "current=" << current <<", lBound=" << lBound << ", center=" << center <<", uBound=" << uBound;
	if (current >= center) {
	  location[0]=1;
	  lBound=center;
	} else {
	  location[0]=0;
	  uBound=center;
	}
	//	std::cout << ", location=" << location << std::endl;
  }
  return location;
}

scheduler::Schedule::LocationType ScheduleArchive::encodeDimensions(
	const scheduler::Schedule::LocationDimensionType& priceDimension,
	const scheduler::Schedule::LocationDimensionType& queueTimeDimension) {
  std::string foo = priceDimension.to_string();
  std::string bar = queueTimeDimension.to_string();
  std::string retval( foo + bar);
  //std::cout << "price: "<<priceDimension << " qt: " << queueTimeDimension << " => combined: " << retval << std::endl; 
  return scheduler::Schedule::LocationType(retval);
}


void ScheduleArchive::updateAllLocations() {
  //std::cout << "Updating the location of all schedules." << std::endl;
  _population.clear();
  std::vector<scheduler::Schedule::Ptr>::iterator it;
  for(  it = _archive->begin(); it < _archive->end(); it++) {
	double qt=(*it)->getTotalQueueTime();
	double p=(*it)->getTotalPrice();
	scheduler::Schedule::LocationDimensionType pDimension=calculateLocation(p, getMinPrice(), getMaxPrice());
	scheduler::Schedule::LocationDimensionType qtDimension=calculateLocation(qt, getMinQueueTime(), getMaxQueueTime());
	scheduler::Schedule::LocationType location=encodeDimensions(pDimension, qtDimension);
	(*it)->setLocation(location);
	std::string sLocation=location.to_string();
	_population[sLocation] = _population[sLocation] + 1;
  }
}

std::string ScheduleArchive::getPopulationStr() {
  std::ostringstream oss;
  oss << "location -> count" << std::endl;
  std::map<std::string, unsigned long>::iterator it;
  for ( it=_population.begin() ; it != _population.end(); it++ )
	oss << (*it).first << " -> " << (*it).second << std::endl;
  return oss.str();
}

const unsigned long ScheduleArchive::getPopulationCount(scheduler::Schedule::LocationType location) {
  return _population[location.to_string()];
}

//const std::string ScheduleArchive::str() {
//  std::ostringstream oss;
//  oss << "ScheduleArchive contains " << _archive->size() << " schedules." << std::endl;
//  oss << " - QT (min/max): "<< getMinQueueTime() << "/" << getMaxQueueTime() << std::endl;
//  oss << " - Price (min/max): " << getMinPrice() << "/" << getMaxPrice() << std::endl;
//  if (_tainted)
//	oss << " - tainted." << std::endl;
//  else
//	oss << " - not tainted." << std::endl;
//  std::vector<scheduler::Schedule::Ptr>::iterator it;
//  for(  it = _archive->begin(); it < _archive->end(); it++) {
//	oss << " * L: " << (*it)->getLocation();
//	oss << ", QT: " << (*it)->getTotalQueueTime();
//	oss << ", P: " << (*it)->getTotalPrice() << std::endl;
//  }
//  //return oss.str();
//  return std::string("foobar.");
//}
