# This file is part of the calana grid workload generator.
# (c) 2008 Mathias Dalheimer, md@gonium.net
#
# The calana grid work$load generator (CGWG) is free software; you can 
# redistribute it and/or modify it under the terms of the GNU General Public 
# License as published by the Free Software Foundation; either version 2 of 
# the License, or any later version.
#
# CGWG is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with CGWG; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
# Read the CGWG location from the environment, warn otherwise
if (ENV["CGWG_HOME"] == nil)
  puts "WARNING: Environment does not define $CGWG_HOME!"
else
  libpath= File.join(File.expand_path(ENV["CGWG_HOME"]), "lib")
  $:.unshift << libpath
end

require "date"

# Locate the report template file
REPORT_TEMPLATE_FILE=File.join(File.expand_path(ENV["CGWG_HOME"]), "lib/analysis-template.tex")
LATEX_CMD="pdflatex -interaction batchmode"

# Creates a PDF that summarizes the current experiment. All 
# previously generated summaries are integrated using latex.
class LatexReport
  def initialize(analysisdir)
    @analysisdir=analysisdir
    @pdfReportFilename="analysis.pdf"
    @texReportFilename="analysis.tex"
  end

  # Creates an analysis document:
  # - Collect all available artefacts and put them into a Hash
  # - Use the template class to integrate the artefacts into the 
  #   tex input file.
  def composeDocument
    @template=buildTemplateFromFile(REPORT_TEMPLATE_FILE)
    @template.setValueHash(generateArtefactHash())
    doc=@template.run()
    texdoc=File.join(@analysisdir, @texReportFilename)
    File.open(texdoc, "w") {|outfile|
      outfile.write(doc)
    }
  end

  # Use latex to create a PDF from the previously generated document
  def runLatex
    #TODO: Waiting for hercules pdflatex installation
  end

  def generateArtefactHash()
    artefacts={}
    # First, put all files from the analysis into the hash.
    Dir.glob(File.join(@analysisdir, "*.pdf")) {|filename|
      key=File.basename(filename, ".pdf")
      #puts "#{key}: #{filename}"
      artefacts[key]=filename
    }
    # Now, generate some metadata
    artefacts["date"]=Date.today()
    artefacts["analysisdir"]=@analysisdir
    artefacts
  end
  
  def buildTemplateFromFile(filename)
    template=nil
    raise "Template not found, assumed #{filename}" unless (File.exists?(filename))
    File.open(filename, "r") {|file|
      content=file.readlines();
      puts content if $verbose
      template=Template.new(content)
    }
    template
  end
end

# Provides a flexible templating engine. Initialize with the template, then 
# add name-value pairs with set, then run the replacement.
class Template
  def initialize(template)
    @template=template.to_s
    @values={}
  end
  def set(name, value)
    @values[name]=value
  end
  def setValueHash(hash)
    @values=hash
  end
  def run()
    @template.gsub(/@@(.*?)@@/) {
      if (!@values.has_key?($1))
        replacement="KEY UNDEFINED"
      else
        replacement=@values[$1].to_s
      end
      replacement
    }
  end
  def to_s
    run()
  end
end

# test routines below
if __FILE__ == $0 
  lr=LatexReport.new("/scratch/md/single-synthetic/run06/analysis")
  lr.composeDocument()
  lr.runLatex();
end
