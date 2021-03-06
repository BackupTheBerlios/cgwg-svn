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
require 'Utils'
require 'R'
require 'Scheduler'
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
      opts.on("-s", "--store PATH", "path to workload collection store") do |store|
        options.store=store
      end
      opts.on("-o", "--output directory","the output directory for result files") do |outdir|
        options.outdir=outdir
      end
      opts.on("-l", "--loadlevel FLOAT","the load level to work on.") do |loadlevel|
        options.loadlevel=loadlevel
      end
      opts.on("-r", "--resource-definition FILE","the resource definition file to use.") do |rfile|
        options.resourcefile=rfile
      end
      opts.on("-nhs", "--noheatingschedule","should the heating phase be skipped?") do |nhs|
        options.noheating=nhs
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
@@config = ConfigManager.new # some global constants etc.
options = Optparser.parse(ARGV)
outdir = options.outdir    
storePath = options.store
loadlevel = options.loadlevel.to_f
resourceDefinitionFile = options.resourcefile
if (options.noheating)
  puts "Disabling heating before cooldown."
  noheating = true
else
  puts "Will heat before cooling down."
  noheating = false
end
$verbose = options.verbose

if storePath == nil or outdir == nil or resourceDefinitionFile == nil
  puts "please read usage note (-h)"
  exit
end

if not File.readable?(File.expand_path(resourceDefinitionFile))
  puts "Cannot read resource definition file: #{resourceDefinitionFile}"
  exit
end

if loadlevel == nil
  puts "please read usage note - loadlevel must be given."
  exit
end

puts "# Simulated Annealing Scheduler"
logfile = "sa-log-#{loadlevel}.txt"
logfileFullPath = File.expand_path(File.join(outdir, logfile))
puts "# Using logfile #{logfileFullPath}"
solutionfile = "sa-schedule-#{loadlevel}.bin"
solutionfileFullPath = File.expand_path(File.join(outdir, solutionfile))
puts "# Using solution file #{solutionfileFullPath}"

puts "# Unmarshalling the store #{storePath}"
store=File.new(storePath, "r");
collection = Marshal.load(store);
store.close;

workload=collection.getWorkload(loadlevel);
if (workload == nil)
  puts "The workload with loadlevel = #{loadlevel} is not available."
  puts("The store claims these workloads:")
  collection.printWorkloadOverview()
  exit
end

nodes=workload.clusterConfig.nodes
jobCount=workload.size()
maxIteration=(workload.size()).to_i
puts "# Using workload with real load #{workload.load} and #{nodes} nodes."
puts "# The workload contains #{jobCount} jobs - using #{maxIteration} iterations per MC loop."

if $verbose
  puts "Printing workload:"
  workload.eachJob{|job|
    puts job
  }
end

# Prevent over-defining methods by loading the code in another class.
class ExternalResourceCode
end
x = ExternalResourceCode.new
resourceDefinitionFile = 'bin/sa-resourcedef-template.rb'
resourceDefinitionFilePath = File.expand_path(resourceDefinitionFile)
x.instance_eval(File.open(resourceDefinitionFilePath).read)
resourceSet = x.generateResourceSet(nodes)

schedule=Schedule.new(workload, resourceSet)
reporter=LogReporter.new()
reporter.setHeader("Temperature\tEnergy\tAccepted");

###
## Start optimization
#
if (noheating) 
  coolingSchedule=GeometricCoolingSchedule.new(0.1, 100, 0.9);
else
  coolingSchedule=HeatingAndGeometricCoolingSchedule.new(0.5, 0.1, 100, 0.9);
end
schedule.initialSolutionRoundRobinResource()
puts "# Initial solution:"
puts schedule.to_s
oldEnergy=schedule.assessSchedule();
puts "# Initial energy: #{oldEnergy}"
accepted=0;
while (temperature = coolingSchedule.nextTemperature(accepted.to_f/maxIteration))
  accepted=0;
  for i in 0..maxIteration do
    oldSolution=schedule.getSolution();
    oldEnergy=schedule.assessSchedule();
    schedule.permutateJobs()
    newEnergy=schedule.assessSchedule();
    if (oldEnergy < newEnergy)
      # The old solution was better than the current one - probabilistic
      # acceptance.
      deltaEnergy = newEnergy - oldEnergy
      probability = Math.exp(-deltaEnergy/temperature)
      chance=rand()
      #puts "oldEnergy < newEnergy: chance=#{chance}, probability=#{probability}" if $verbose
      if (probability > chance)
        #puts "Accepting new solution, although its worse." if $verbose
        accepted+=1;
      else
        #puts "Restoring old solution" if $verbose
        schedule.setSolution(oldSolution)
      end
    else
      #puts "Found better solution - already current state." if $verbose
      accepted+=1;
    end
  end
  currentEnergy=schedule.assessSchedule
  #schedule.sanityCheck()
  puts "# Temperature: #{temperature}, best energy: #{currentEnergy}, accepted: #{accepted}/#{maxIteration}"
  reporter.addLine("#{temperature}\t#{currentEnergy}\t#{accepted}");
end
reporter.dumpToFile(logfileFullPath);

#puts "# Final solution:"
#puts schedule.to_s

puts "Saving solution to file #{solutionfileFullPath}"
schedule.saveToFile(solutionfileFullPath)
