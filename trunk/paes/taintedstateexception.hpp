#ifndef PAES_TAINTEDSTATEEXCEPTION_HPP
#define PAES_TAINTEDSTATEEXCEPTION_HPP 1

#include <stdexcept>


namespace scheduler {
  class TaintedStateException : public std::runtime_error {
	public:
	  TaintedStateException (const std::string& reason = "Object state is tainted.") 
		: std::runtime_error(reason) {};
  };
}

#endif /* PAES_TAINTEDSTATEEXCEPTION_HPP */

