#include "random.hpp"
#include <cstdlib>
#include <ctime>
#include <limits.h>
#include <iostream>


using namespace util;

RNG& RNG::instance() {
  static RNG instance;
  return instance;
}

double RNG::uniform_deviate ( int seed ) {
  return seed * ( 1.0 / ( RAND_MAX + 1.0 ) );
}

unsigned int RNG::uniform_derivate_int() {
  return (unsigned int) uniform_deviate ( rand() ) * 10;
}

unsigned int RNG::uniform_derivate_ranged_int(unsigned int min, unsigned int max) {
  return (unsigned int) (min + uniform_deviate ( rand() ) * ((max+1) - min));
}

void RNG::time_seed() {
  time_t now = time ( 0 );
  unsigned char *p = (unsigned char *)&now;
  unsigned seed = 0;
  size_t i;

  for ( i = 0; i < sizeof now; i++ )
	seed = seed * ( UCHAR_MAX + 2U ) + p[i];

  set_seed(seed);
}

unsigned int RNG::get_seed() {
  return _seed;
}

void RNG::set_seed(unsigned int seed) {
  //std::cout << "RNG: setting seed value to " << seed << std::endl;
  _seed=seed;
  srand(_seed);
}
