#ifndef PAES_RANDOM_HPP
#define PAES_RANDOM_HPP 1

namespace util {
  /**
   * Wraps random functions.
   * see http://eternallyconfuzzled.com/arts/jsw_art_rand.aspx
   */
  class RNG {
	public:
	  static RNG& instance();

	  double uniform_deviate ( int seed );
	  unsigned int uniform_derivate_int();
      void set_seed(unsigned int seed);
      unsigned int get_seed();
	  /**
	   * min: smallest allowed value, max: biggest allowed value (inclusive)
	   * returns rand in [min, max]
	   */
	  unsigned int uniform_derivate_ranged_int(unsigned int min, unsigned int max);
	  ~RNG(){};

	private:
	  RNG() : _seed(0) { time_seed(); };
	  RNG (const RNG& original);
	  RNG& operator= (const RNG& rhs);
	  void time_seed();
      unsigned int _seed;
  };

}

#endif /* PAES_RANDOM_HPP */
