#ifndef PAES_WORKLOAD_FACTORY_HPP
#define PAES_WORKLOAD_FACTORY_HPP 1

#include <common.hpp>
#include <workload.hpp>

namespace scheduler {
  class FileWorkloadFactory {
	public:
	  typedef std::tr1::shared_ptr<FileWorkloadFactory> Ptr;
	  FileWorkloadFactory (const std::string& filename) :
		_filename(filename) {};
	  virtual ~FileWorkloadFactory() {};
	  scheduler::Workload::Ptr parseWorkload();

	private:
	  FileWorkloadFactory (const FileWorkloadFactory& original);
	  FileWorkloadFactory& operator= (const FileWorkloadFactory& rhs);
	  std::string _filename;
  };
}


#endif /* PAES_WORKLOAD-FACTORY_HPP */

