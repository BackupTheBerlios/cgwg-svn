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
LATEX_CMD="latex -interaction batchmode"

# Creates a PDF that summarizes the current experiment. All 
# previously generated summaries are integrated using latex.
class LatexExperimentReport
  def initialize(analysisdir)
    @analysisdir=analysisdir
    @psReportFilename="analysis.ps"
    @pdfReportFilename="analysis.pdf"
    @dviReportFilename="analysis.dvi"
    @texReportFilename="analysis.tex"
    @texdoc=File.join(@analysisdir, @texReportFilename)
  end

  # convenience function to create a report.
  def createReport()
    composeDocument()
    runLatex();
  end

  # Creates an analysis document:
  # - Collect all available artefacts and put them into a Hash
  # - Use the template class to integrate the artefacts into the 
  #   tex input file.
  def composeDocument
    @template=buildTemplateFromFile(REPORT_TEMPLATE_FILE)
    @template.setValueHash(generateArtefactHash())
    doc=@template.run()
    File.open(@texdoc, "w") {|outfile|
      outfile.write(doc)
    }
  end

  # Use latex to create a PDF from the previously generated document
  def runLatex
    commandline="#{LATEX_CMD} -output-directory #{@analysisdir} #{@texdoc}"
    puts "using commandline: #{commandline}" if $verbose
    stdout = %x[#{commandline}]
    puts "Latex (Exitcode: #{$?}) said: #{stdout}" if $verbose

    puts "converting to postscript" if $verbose
    fullDVIFile = File.join(@analysisdir, @dviReportFilename)
    fullPSFile = File.join(@analysisdir, @psReportFilename)
    commandline = "dvips -o #{fullPSFile} #{fullDVIFile}"
    puts "using commandline: #{commandline}" if $verbose
    cmd = %x[#{commandline}]
    puts "dvips (Exitcode: #{$?}) said: #{cmd}" if $verbose

    puts "converting to PDF" if $verbose
    fullPSFile = File.join(@analysisdir, @psReportFilename)
    fullPDFFile = File.join(@analysisdir, @pdfReportFilename)
    commandline = "ps2pdf #{fullPSFile} #{fullPDFFile}"
    puts "using commandline: #{commandline}" if $verbose
    cmd = %x[#{commandline}]
    puts "ps2pdf (Exitcode: #{$?}) said: #{cmd}" if $verbose
  end

  # artifact: AE, artefact: BE!
  def generateArtefactHash()
    artefacts={}
    # First, put all files from the analysis into the hash.
    Dir.glob(File.join(@analysisdir, "*.eps")) {|filename|
      key=File.basename(filename, ".eps")
      puts "#{key}: #{filename}" if $verbose
      artefacts[key]=filename
    }
    # Build a list of special keys pointing to the workload ranks
    # 10%, 50%, 90% load level files.
    loadlevels=Array.new
    artefacts.each{|key, value|
      # use only one filetype to create list.
      if key =~ /^price-\d\./
        loadlevel = key.gsub(/^price-/, "")
        loadlevels << loadlevel
      end
    }
    loadlevels.sort!
    if $verbose 
      loadlevels.each{|level|
        puts "Found loadlevel #{level}"
      }
    end
    lowLevelIndex = (loadlevels.size * 0.1).to_i
    lowLevel = loadlevels[lowLevelIndex]
    midLevelIndex = (loadlevels.size * 0.5).to_i
    midLevel = loadlevels[midLevelIndex]
    highLevelIndex = (loadlevels.size * 0.9).to_i
    highLevel = loadlevels[highLevelIndex]
    if $verbose
      puts "low level index: #{lowLevelIndex}, pointing to #{lowLevel}" 
      puts "mid level index: #{midLevelIndex}, pointing to #{midLevel}"
      puts "high level index: #{highLevelIndex}, pointing to #{highLevel}"
    end
    # put the load levels in the artefacts hash.
    artefacts["lowload"]=lowLevel
    artefacts["midload"]=midLevel
    artefacts["highload"]=highLevel
    # for all artefacts in the hash that match one of the load levels:
    # replace the load number in the key with the load tag and add to
    # the artefacts hash.
    # (1) For all load levels
    levels = { "#{lowLevel}" => "lowload", 
              "#{midLevel}" => "midload",
              "#{highLevel}" => "highload"
             }
    levels.each{|level, loadname|
      # (2) For all artefacts
      artefacts.each{|key, value|
        if key =~ /#{level}/
          newkey = key.gsub(/#{level}/, loadname)
          artefacts[newkey]=value
          puts "#{loadname}: #{key} -> generated new key #{newkey}" if $verbose
        end
      }
    }
    # finally, generate some metadata
    artefacts["date"]=Date.today()
    artefacts["analysisdir"]=@analysisdir
    artefacts
  end
  
  def buildTemplateFromFile(filename)
    template=nil
    raise "Template not found, assumed #{filename}" unless (File.exists?(filename))
    File.open(filename, "r") {|file|
      content=file.readlines();
      #puts content if $verbose
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
  $verbose = true
  lr=LatexExperimentReport.new("/scratch/md/single-synthetic/run01/analysis")
  lr.createReport()
end
