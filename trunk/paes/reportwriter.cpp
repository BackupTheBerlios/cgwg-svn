#include "reportwriter.hpp"
#include <fstream>
#include <sstream>

using namespace util;


void ReportWriter::addReportLine(const std::string& line) {
  _reportLines.push_back(line);
}

void ReportWriter::addHeaderLine(const std::string& line) {
  _reportLines.push_back(line);
}
void ReportWriter::writeReport() {
  std::cout << "Saving report to file " << _outfile << std::endl;
  std::ofstream myfile (_outfile.c_str());
  if (myfile.is_open()) {
    std::vector<std::string>::iterator it;
    for(it = _reportHeader.begin(); it < _reportHeader.end(); it++) {
      myfile << "# " << (*it) << std::endl;
    }
    for(it = _reportLines.begin(); it < _reportLines.end(); it++) {
      myfile << (*it) << std::endl;
    }
	myfile.close();
  } else {
	std::cerr << "Unable to open file, aborting" << std::endl; 
	exit(-1);
  }
}
