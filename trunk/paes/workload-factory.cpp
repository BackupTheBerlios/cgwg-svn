#include "workload-factory.hpp"
#include <fstream>
#include <sstream>
#include <string>



using namespace scheduler;

scheduler::Workload::Ptr FileWorkloadFactory::parseWorkload() {
  scheduler::Workload::Ptr retval(new scheduler::Workload());
  std::cout << "Loading workload from file " << _filename << std::endl;
  std::string line;
  std::ifstream myfile (_filename.c_str());
  if (myfile.is_open()) {
	while (! myfile.eof() ) {
	  getline(myfile,line);
	  // first, ignore all lines starting with '#'
	  if (line[0] == '#')
		continue;
	  std::istringstream iss(line, std::istringstream::in);
	  scheduler::Job::IDType jobid;
	  iss >> jobid;
	  double submit_time;
	  iss >> submit_time;
	  double run_time;
	  iss >> run_time;
	  double wall_time;
	  iss >> wall_time;
	  unsigned int size;
	  iss >> size;
	  scheduler::Job::Ptr job(new scheduler::Job(jobid, submit_time, run_time, wall_time, size));
	  if (!myfile.eof()) { 
		// check for eof again - otherwise, we might duplicate the last job again,
		retval->add(job);
		//std::cout << job->str() << std::endl;
	  }
	}
	myfile.close();
  } else {
	std::cerr << "Unable to open file, aborting" << std::endl; 
	exit(-1);
  }
  return retval;
}
