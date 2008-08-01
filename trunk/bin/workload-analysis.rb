#!/usr/bin/env ruby
# This file is part of the calana grid workload generator.
# (c) 2006 Mathias Dalheimer, md@gonium.net
#
# The calana grid workload generator (CGWG) is free software; you can 
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
#  puts "Using libraty path #{$:.join(":")}" 
end


require 'rubygems'
require 'Models'
require 'Workload'
require 'Helpers'
require 'Gnuplot'
require 'R'
require 'Latex'
require 'optparse'
require 'ostruct'

###
## This is the main workload generator file. You should look at the
## ConfigManager class (in lib/Helpers.rb) and the main program below.
#

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
        options.inplace = false
        options.encoding = "utf8"
        options.verbose = false
        opts = OptionParser.new do |opts|
            opts.banner = "Usage: workload-analysis.rb [options]"
            opts.separator ""
            opts.separator "Specific options:"
            # Mandatory argument.
            opts.on("-s", "--store PATH", "path to workload collection store") do |store|
                options.store=store
            end
            opts.on("-o", "--output directory","the output directory for the report files") do |outdir|
                options.outdir=outdir
            end
            opts.on("-l", "--loadlevel [double]","loadlevel to analyze") do |loadlevel|
                options.loadlevel=loadlevel
            end

            # Boolean switch.
            opts.on("-v", "--verbose", "Run verbosely") do |v|
                options.verbose = v
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
## Script startup
#

options = Optparser.parse(ARGV)
outdir = options.outdir    
storePath = options.store

$verbose = options.verbose

if storePath == nil or outdir == nil
    print "please read usage note (-h)\n"
    exit
end

print "Workload Collection analysis script\n"

puts "Unmarshalling the store #{storePath}"
store=File.new(storePath, "r");
collection = Marshal.load(store);
store.close;

if $verbose
    puts("The store claims these workloads:")
    collection.printWorkloadOverview()
end

collection.eachWorkload{|w|
  analysator=WorkloadAnalysis.new(w, outdir)
  analysator.plotUtilization()
  analysator.plotGraphs()
}
puts "Generating a PDF summary report"
lr=LatexReport.new(outdir, "workload", "runtimes-")
lr.createReport()

puts "Hint: Create a movie with\nmencoder \"mf://allocationsamples*.png\" -mf fps=3 -o output.avi -ovc lavc"


exit

