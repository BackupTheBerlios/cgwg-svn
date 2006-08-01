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

require 'rubygems'
require 'lib/Models'
require 'lib/Workload'
require 'lib/Helpers'
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

class Event 
    include Comparable
    attr_accessor :time
    def initialize(time)
        @time=time
        @amount = 0
        @add=false
        @sub=false
    end
    def addAmount(a)
        if (a == -1)
            raise "Invalid amount!"
        end
        @amount = a
        @add=true
    end
    def subAmount(a)
        if (a == -1)
            raise "Invalid amount!"
        end
        @amount = a
        @sub=true
    end
    def <=>(other)
        @time <=> other.time
    end
    def accumulate(accumulator)
        if @add
            accumulator=accumulator + @amount
        end
        if @sub
            accumulator=accumulator - @amount
        end
        return accumulator
    end
    def to_s
        retval = "#{@time}: "
        if @add
            retval << "+#{@amount}"
        end
        if @sub
            retval << "-#{@amount}"
        end
        return retval
    end
end

# =============================================================
# = Prints a 2-dimensional dataset , connects data with lines =
# =============================================================
def gnuPlot2Lines(inFile, outFile, title, xlabel, ylabel, xcolumn, ycolumn, xmaxrange, ymaxrange)
    inputFile = inFile
    outputFile = outFile
    gnuplotCmd = <<-EOC
set terminal postscript eps color
set output \\"#{outputFile}\\"
set xlabel \\"#{xlabel}\\"
set ylabel \\"#{ylabel}\\"
set xrange [0:#{xmaxrange}]
set yrange [0:#{ymaxrange}]
set size 2,2
plot \\"#{inputFile}\\" using #{xcolumn}:#{ycolumn} axis x1y1 title \\"#{title}\\" with linespoints
EOC
    runGnuPlot(gnuplotCmd, inFile, outFile)
end

# ========================================================
# = Runs gnuplot with the given config, then runs ps2pdf =
# ========================================================
def runGnuPlot (gnuplotCmd, inputFile, outputFile)
    outPDFFile = outputFile.sub(/eps/, "pdf")
    outPNGFile = outputFile.sub(/eps/, "png")
    puts "Using gnuplot command: \n#{gnuplotCmd}\n" if $verbose
    puts "running gnuplot to create #{outputFile}"
    cmd = `echo -n "#{gnuplotCmd}" | gnuplot`
    print "Gnuplot said: \n#{cmd}\n" if $verbose
    print "converting to PDF\n" if $verbose
    cmd = `ps2pdf #{outputFile} #{outPDFFile}`
    print "ps2pdf said: #{cmd}\n" if $verbose
    cmd = `convert #{outputFile} -scale 800x600 #{outPNGFile}`
end
                                                        

###
## You may also want to check out the ConfigManager class in lib/Helpers.rb.
#
options = Optparser.parse(ARGV)
outdir = options.outdir    
storePath = options.store

$verbose = options.verbose

if storePath == nil or outdir == nil
    print "please read usage note (-h)\n"
    exit
end

###
## Script startup
#
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
levels = Array.new

puts ("Sampling load data for each loadlevel")
collection.eachWorkload{|w|
    @events=Array.new
    loadlevel=w.calculateLoadLevel()
    levels << loadlevel
    levelString = sprintf("%1.3f", loadlevel)
    datafilepath=outdir+"/allocation-#{levelString}.txt"
    picfilepath=outdir+"/allocation-#{levelString}.eps"
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
        startEvent=Event.new(startTime)
        startEvent.addAmount(size)
        endEvent=Event.new(endTime)
        endEvent.subAmount(size)
        @events.push(startEvent) 
        @events.push(endEvent)
    }
    @events.sort!
    accumulator = 0
    @events.each{|event|
        #puts "Processing: #{event}"
        #puts "before: #{accumulator}"
        accumulator=event.accumulate(accumulator)
        #puts "after: #{accumulator}"
        datafile.print("#{event.time}\t#{accumulator}\n")
        puts "#{event.time}\t#{accumulator}" if $verbose
        # Update max values
        maxTime = event.time if event.time > maxTime
        maxNodes = accumulator if accumulator > maxNodes
    }
    datafile.close
}

puts "Maximum nodes: #{maxNodes}, maximum time: #{maxTime}"
puts "Plotting..."
levels.each{|loadlevel|
    levelString = sprintf("%1.3f", loadlevel)
    datafilepath=outdir+"/allocation-#{levelString}.txt"
    picfilepath=outdir+"/allocation-#{levelString}.eps"
    puts "Plotting workload..." if $verbose
    gnuPlot2Lines(datafilepath, picfilepath, "Accumulated allocation (load = #{loadlevel})", "time", "requested nodes", 1, 2, maxTime, maxNodes)
}

puts "Hint: Create a movie with mencoder \"mf://*.png\" -mf fps=3 -o output.avi -ovc lavc"


exit

