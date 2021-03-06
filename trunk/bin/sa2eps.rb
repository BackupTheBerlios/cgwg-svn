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
#gem 'builder' #we need xml builder
#require 'builder/xmlmarkup'
require 'R'
require 'optparse'
require 'ostruct'

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
      opts.banner = "Usage: #{$0} [options]"
      opts.separator ""
      opts.separator "Specific options:"
      # Mandatory argument.
      opts.on("-d", "--directory directory","the directory for input and result files") do |outdir|
        options.outdir=outdir
      end
      opts.on("-l", "--loadlevel FLOAT","the load level to work on.") do |loadlevel|
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
loadlevel = options.loadlevel.to_f
$verbose = options.verbose

if outdir == nil
  puts "please read usage note - directory must be given."
  exit
end

if loadlevel == nil
  puts "please read usage note - loadlevel must be given."
  exit
end

puts "# Simulated Annealing Scheduler - EPS evaluation generator"
logfile = "sa-log-#{loadlevel}.txt"
logfileFullPath = File.expand_path(File.join(outdir, "sa-log-#{loadlevel}.txt"))
puts "# Using logfile #{logfileFullPath}"

puts "# Generating graphs from logfile."
plotEngine=SA_Analysis.new(outdir, logfile, loadlevel)
plotEngine.plotSingleRun();
