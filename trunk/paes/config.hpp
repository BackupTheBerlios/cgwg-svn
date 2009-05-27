#ifndef CONFIG_HPP
#define CONFIG_HPP 1
#include <string>
#include <resourcepool.hpp>
#include <stdexcept>


namespace config {
  enum ConfigName {
	THREE_SIMPLE_RESOURCES
  } ;
  /**
   * This string defines the configuration to be built. see config.cpp
   * for valid values.
   */
  const static int CONFIG_NAME=THREE_SIMPLE_RESOURCES;
  const static unsigned int LOCATION_DIMENSION_SIZE=32;
  const static unsigned int NUM_LOCATION_BITS=2*LOCATION_DIMENSION_SIZE;
  const static size_t ARCHIVE_SIZE=1000;
  const static unsigned long MAX_ITERATION=10000000;

  // Returns a string describing the current configuration as set above.
  const std::string getConfigString();
  // Builds a configuration
  scheduler::ResourcePool::Ptr createResourcePool();
  // private factory methods.
  scheduler::ResourcePool::Ptr create3SimpleResources();
}


#endif /* CONFIG_HPP */

