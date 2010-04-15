#!/usr/bin/env ruby
# This file is part of the calana grid workload generator.
# (c) 2008 Christian Bischof, christianbischof@gmx.de
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

require 'optparse'
require 'ostruct'
require 'hpricot'

###
## Commandline parser
#
class Optparser
    CODES = %w[iso-2022-jp shift_jis euc-jp utf8 binary]
    CODE_ALIASES = { "jis" => "iso-2022-jp", "sjis" => "shift_jis" }
    #
    # Return a structure describing the options.
    #
    def self.parse(args)
        # The options specified on the command line will be collected in *options*.
        # We set default values here.
        options = OpenStruct.new
        opts = OptionParser.new do |opts|
            opts.banner = "Usage: workload2paes.rb [options]"
            opts.separator ""
            opts.separator "Specific options:"
            # Mandatory argument.
            opts.on("-i", "--input-file PATH", "input workload file") do |i|
                options.inputFileName=i
            end
            opts.on("-o", "--output-path PATH","output directory for saving results") do |o|
                options.outputDir=o
            end
            opts.on("-f", "--force","ignore existing output file") do |f|
                options.force=f
            end
    
            opts.on_tail("-h", "--help", "Show this message") do
                puts opts
                exit
            end
        end
        opts.parse!(args)
        options
    end
end

###
## Script begins here
#
puts "Calana workload to paes workload wrapper"

options = Optparser.parse(ARGV)

inputFileName = options.inputFileName
outputDir = options.outputDir
force = options.force

if inputFileName == nil or outputDir == nil
  puts "please ready usage note (-h)"
  puts
  puts "mandatory parameters: i, o"
  exit
end

# open file for reading
inputFile = File.expand_path(inputFileName)
if !File.exists?(inputFile)
  puts "Input file does not exist.. aborting"
  exit
else
  puts "Input file exists.. opening"
  @doc = Hpricot.XML(open(inputFile))
end

outputFile = File.expand_path("#{outputDir}/workload.xml")
if File.exists?(outputFile) and !force
  puts "Output file already exists.. aborting"
  exit
else
  puts "Creating output file.."
  File.open(outputFile, "w") {|handle|
    handle.puts "#\tJID\tSubmitTime\tRunTime\tWallTime\tSize"
    (@doc/"job").each {|elt|
      jobId = elt.get_attribute("id")
      jobId = jobId.split("-")[1]
      submittime = (elt/"timing").first.get_attribute("submittime")
      runtime = (elt/"actual").first.get_attribute("runtime")
      walltime = (elt/"requested").first.get_attribute("walltime")
      size = (elt/"actual").first.get_attribute("cpus")

      handle.puts "#{jobId}\t#{submittime}\t#{runtime}\t#{walltime}\t#{size}"
    }
  }
  puts ".. done"
end

