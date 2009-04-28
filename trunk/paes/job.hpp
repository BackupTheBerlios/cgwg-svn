#ifndef PAES_JOB_HPP
#define PAES_JOB_HPP 1

#include <common.hpp>
#include <string>
#include <sstream>
#include <limits.h>
//#include <resource.hpp>


namespace scheduler {
  class Job {
	public:
	  typedef std::tr1::shared_ptr<Job> Ptr;
	  typedef unsigned int IDType;
	  static const IDType JOBID_MAX = UINT_MAX;

	  Job (IDType jobid, double submit_time, double run_time, double wall_time, unsigned int size) :
		_jobid(jobid), _submit_time(submit_time), _run_time(run_time), _wall_time(wall_time), _size(size) {};
	  virtual ~Job() {};

	  const IDType getJobID() const { return _jobid; }
	  const double getSubmitTime() const { return _submit_time; }
	  const double getRunTime() const { return _run_time; }
	  const double getWallTime() const { return _wall_time; }
	  const unsigned int getSize() const { return _size; }
	 // void setResource(const scheduler::Resource::IDType& resource) { _resource=resource;}
	 // const scheduler::Resource::IDType getResource() const { return _resource; }
	  const std::string str() const;

	private:
	  Job (const Job& original);
	  Job& operator= (const Job& rhs);
	  IDType _jobid;
	  double _submit_time;
	  double _run_time;
	  double _wall_time;
	  unsigned int _size;
//	  scheduler::Resource::IDType _resource;
  };

}


#endif /* PAES_JOB_HPP */

