#ifndef CONFIG_HPP
#define CONFIG_HPP 1
#include <string>
#include <resourcepool.hpp>
#include <stdexcept>


namespace config {
  enum ConfigName {
	THREE_SIMPLE_RESOURCES,
  ADAPTABLE_SIMPLE_RESSOURCES
  } ;
  /**
   * This string defines the configuration to be built. see config.cpp
   * for valid values.
   */
  const static int CONFIG_NAME=ADAPTABLE_SIMPLE_RESSOURCES;
  const static unsigned int LOCATION_DIMENSION_SIZE=32;
  const static unsigned int NUM_LOCATION_BITS=2*LOCATION_DIMENSION_SIZE;
  const static size_t ARCHIVE_SIZE=1000;
  const static unsigned long MAX_ITERATION=10000000;

  // Sets the number, timePrices and basePrices for the adabtable resources
  const static unsigned int LOOP_COUNT = 10;
  const static double ADAPTABLE_BASE_PRICES[LOOP_COUNT] = {
    300, 245.43, 202.52, 189.93, 185.2, 186.93, 112.48, 279.87, 100, 247.99
  };
  const static double ADAPTABLE_TIME_PRICES[LOOP_COUNT] = {
    1.94, 2.79, 1.2, 3.0, 0.92, 2.01, 1.89, 2.03, 0.5, 1.13
  };
  // end adaptable resources

  // Returns a string describing the current configuration as set above.
  const std::string getConfigString();
  // Builds a configuration
  scheduler::ResourcePool::Ptr createResourcePool();
  // private factory methods.
  scheduler::ResourcePool::Ptr create3SimpleResources();
  scheduler::ResourcePool::Ptr createAdaptableSimpleResources();
}


#endif /* CONFIG_HPP */

