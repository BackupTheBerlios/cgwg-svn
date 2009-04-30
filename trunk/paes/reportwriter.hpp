#ifndef PAES_REPORTWRITER_HPP
#define PAES_REPORTWRITER_HPP 1

#include <common.hpp>
#include <vector>

namespace util {
  class ReportWriter {
    public:
      typedef std::tr1::shared_ptr<ReportWriter> Ptr;
      ReportWriter (const std::string& outfile) : 
        _outfile(outfile), _reportHeader(), _reportLines() {};
      virtual ~ReportWriter() {};
      void addHeaderLine(const std::string& header);
      void addReportLine(const std::string& line);
      void writeReport();

    private:
      ReportWriter (const ReportWriter& original);
      ReportWriter& operator= (const ReportWriter& rhs);
      std::string _outfile;
      std::vector<std::string> _reportHeader;
      std::vector<std::string> _reportLines;
  };
}


#endif /* PAES_REPORTWRITER_HPP */

