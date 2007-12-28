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

$LOAD_PATH << File.expand_path(File.dirname(__FILE__))
require 'rubygems'
require 'Models'
require 'Workload'
require 'Helpers'
require 'Gnuplot'
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

maxTime = 0
maxNodes = 0
intermediateTimeStep=100
levels = Array.new

puts ("Sampling load data for each loadlevel - using intermediateTimeStep=#{intermediateTimeStep}")
collection.eachWorkload{|w|
    @events=Array.new
    capacity = w.clusterConfig.nodes
    loadlevel=w.calculateLoadLevel()
    levelString = sprintf("%1.3f", loadlevel)
    levels << levelString
    datafilepath=outdir+"/allocationsamples-#{levelString}.txt"
    picfilepath=outdir+"/allocationsamples-#{levelString}.eps"
    puts("Working on load level #{loadlevel}, sampling to #{datafilepath}")
    datafile=File.new(datafilepath, "w")
    datafile.print("time\trequested nodes\n")
    w.eachJob{|job|
        ###
        ## Todo: Think about the timing!
        #
        startTime=job.submitTime
        endTime=startTime + job.runTime
        size=job.numberAllocatedProcessors
        startEvent=AccumulatorSampleEvent.new(startTime)
        startEvent.addAmount(size)
        endEvent=AccumulatorSampleEvent.new(endTime)
        endEvent.subAmount(size)
        @events.push(startEvent) 
        @events.push(endEvent)
    }
    @events.sort!
    accumulator = 0
    lastEventTime=0
    sumLoadSamples = 0.0
    @events.each{|event|
        #puts "Processing: #{event}"
        #puts "before: #{accumulator}"
        oldAccumulator=accumulator
        accumulator, eventTime=event.accumulate(accumulator)
        #puts "got: acc=#{accumulator}, time=#{eventTime}"
        #puts "after: #{accumulator}"
        intermediateTime=lastEventTime
        while (intermediateTime < eventTime)
          datafile.print("#{intermediateTime}\t#{oldAccumulator}\n")
          intermediateTime+=intermediateTimeStep
        end
        datafile.print("#{event.time}\t#{accumulator}\n")
        puts "#{event.time}\t#{accumulator}" if $verbose
        # Update max values
        maxTime = event.time if eventTime > maxTime
        maxNodes = accumulator if accumulator > maxNodes
        sumLoadSamples += (accumulator.to_f * (eventTime - lastEventTime))
        lastEventTime = eventTime
        #puts "Load info: sum=#{sumLoadSamples}, numLoadSamples=#{numLoadSamples}, lastEventTime=#{lastEventTime}"
    }
    datafile.close
    avgLoad = sumLoadSamples / (capacity * maxTime)
    puts "The average load for loadlevel #{loadlevel} is #{avgLoad}, maxNodes = #{maxNodes}"
}

puts "Maximum nodes: #{maxNodes}, maximum time: #{maxTime}"
puts "Plotting..."
levels.each{|levelString|
    datafilepath=outdir+"/allocationsamples-#{levelString}.txt"
    picfilepath=outdir+"/allocationsamples-#{levelString}.eps"
    puts "Plotting workload..." if $verbose
    gnuPlot2Lines(datafilepath, picfilepath, "Accumulated allocation (load = #{levelString})", "time", "requested nodes", 1, 2, maxTime, maxNodes)
}

puts "Hint: Create a movie with\nmencoder \"mf://*.png\" -mf fps=3 -o output.avi -ovc lavc"


exit

