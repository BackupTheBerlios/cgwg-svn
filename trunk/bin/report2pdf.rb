#!/usr/bin/env ruby
# This file is part of the calana grid work$load generator.
# (c) 2006 Mathias Dalheimer, md@gonium.net
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
            opts.banner = "Usage: calana2r.rb [options]"
            opts.separator ""
            opts.separator "Specific options:"
            # Mandatory argument.
            opts.on("-i", "--input directory", "the input file in calanasim format") do |indir|
                options.indir=indir
            end
            opts.on("-o", "--output directory","the output directory for the report files") do |outdir|
                options.outdir=outdir
            end
            opts.on("-l", "--load FLOAT", "the load level of the input
            file, e.g. 0.25") do |load|
                options.load=load
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

# ========================================================
# = Runs gnuplot with the given config, then runs ps2pdf =
# ========================================================
def runGnuPlot (gnuplotCmd, inFile, outFile)
    inputFile = $inDir+"/"+inFile
    outputFile = $outDir+"/"+outFile
    outPDF = outFile.sub(/eps/, "pdf")
    outPDFFile = $outDir+"/"+outPDF
    puts "Using gnuplot command: \n#{gnuplotCmd}\n" if $verbose
    puts "running gnuplot to create #{outFile}"
    cmd = `echo -n "#{gnuplotCmd}" | gnuplot`
    print "Gnuplot said: \n#{cmd}\n" if $verbose 
    print "converting to PDF\n" if $verbose
    cmd = `ps2pdf #{outputFile} #{outPDFFile}`
    print "ps2pdf said: #{cmd}\n" if $verbose    
end

# ==================================
# = Prints a 2-dimensional dataset =
# ==================================
def gnuPlot2Data(inFile, outFile, title, xlabel, ylabel, xcolumn, ycolumn)
    inputFile = $inDir+"/"+inFile
    outputFile = $outDir+"/"+outFile
    gnuplotCmd = <<-EOC
set terminal postscript eps enhanced
set output \\"#{outputFile}\\"
set xlabel \\"#{xlabel}\\"
set ylabel \\"#{ylabel}\\"
plot \\"#{inputFile}\\" using #{xcolumn}:#{ycolumn} axis x1y1 title \\"#{title}\\"
EOC
    runGnuPlot(gnuplotCmd, inFile, outFile)
end


# ======================================
# = Prints a multi-dimensional dataset =
# ======================================
def gnuPlotMultiData(inFile, outFile, title, xlabel, ylabel, columns)
    inputFile = $inDir+"/"+inFile
    outputFile = $outDir+"/"+outFile
    gnuplotCmd = <<-EOC
set terminal postscript eps enhanced
set output \\"#{outputFile}\\"
set xlabel \\"#{xlabel}\\"
set ylabel \\"#{ylabel}\\"
EOC
    plotCmd="\nplot "
    maxIndex = columns.length()
    columns.each_index{|index|
        column = index+2
        if (index < maxIndex-1)
            tmp = <<-EOC
\\"#{inputFile}\\" using 1:#{column} title \\"#{columns[index]}\\" with steps, \\
EOC
        else
            tmp = <<-EOC
\\"#{inputFile}\\" using 1:#{column} title \\"#{columns[index]}\\" with steps
EOC
        end
        plotCmd << tmp
    }
    runGnuPlot(gnuplotCmd<<plotCmd, inFile, outFile)    
end

def discoverEntities(inFile)
    file = File.new($inDir+"/"+inFile, "r")
    entityLine = ""
    file.each_line {|line|
        if line =~ /#entities:/
            entityLine = line.sub(/#entities:/, "")
            entityLine.strip!
            break
        end
    }
    file.close()
    entities = entityLine.split(";")
    entities.compact!
    if $verbose
        entities.each{|entity|
            puts "#{entity}\n" 
        }
    end
    return entities
end

###
## Script begins here
#
print "report to PDF converter\n"
   
options = Optparser.parse(ARGV)
    
$inDir = options.indir
$outDir = options.outdir
$load = options.load
$verbose = options.verbose

if $inDir == nil or $outDir == nil or $load == nil
    print "please read usage note (-h)\n"
    exit
end

gnuPlot2Data("price-rt-preference-#{$load}.txt", "price-pref-#{$load}.eps", 
    "Price vs. PricePreference", "pricePref", "pricePerSecond", 2, 1)
gnuPlot2Data("price-rt-preference-#{$load}.txt", "perf-pref-#{$load}.eps", 
    "Queuetime vs. PerfPreference", "perfPref", "queuetime", 4, 3)

    #names = []
    #for i in 1..50
    #names << "agent"+i.to_s
    #end
    #puts "#{names}"
    #names=["Agent1", "Agent2", "Agent3"]

names = discoverEntities("utilization-#{$load}.txt")
gnuPlotMultiData("utilization-#{$load}.txt", "utilization-#{$load}.eps", 
    "Utilization per agent", "time", "utilization", names)
names = discoverEntities("queuelength-#{$load}.txt")
gnuPlotMultiData("queuelength-#{$load}.txt", "queuelength-#{$load}.eps", 
    "Queue length per agent", "time", "queue length", names)
