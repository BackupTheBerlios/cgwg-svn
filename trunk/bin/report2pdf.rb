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

def gnuPlot(inFile, outFile, title, xlabel, ylabel, xcolumn, ycolumn)
    inputFile = $inDir+"/"+inFile
    outputFile = $outDir+"/"+outFile
    outPDF = outFile.sub(/eps/, "pdf")
    outPDFFile = $outDir+"/"+outPDF
    gnuplotCmd = <<-EOC
set terminal postscript eps enhanced
set output \\"#{outputFile}\\"
#set logscale y
#set logscale y2
#set format y "10^{%L}"
#set xtics ("CTC" 1, "1 Agent" 2, "2 Agents" 3, "3 Agents" 4)
set xlabel \\"#{xlabel}\\"
set ylabel \\"#{ylabel}\\"
#set yrange [0:100000000]
#set boxwidth 0.75
plot \\"#{inputFile}\\" using #{xcolumn}:#{ycolumn} axis x1y1 title \\"#{title}\\"
EOC
puts "Using gnuplot command: \n#{gnuplotCmd}\n" if $verbose
puts "running gnuplot to create #{outFile}"
cmd = `echo -n "#{gnuplotCmd}" | gnuplot`
print "Gnuplot said: \n#{cmd}\n" if $verbose 
print "converting to PDF\n" if $verbose
cmd = `ps2pdf #{outputFile} #{outPDFFile}`
print "ps2pdf said: #{cmd}\n" if $verbose
end

###
## Script begins here
#
print "report to PDF converter\n"
   
options = Optparser.parse(ARGV)
    
$inDir = options.indir
$outDir = options.outdir
$verbose = options.verbose

if $inDir == nil or $outDir == nil 
    print "please read usage note (-h)\n"
    exit
end

gnuPlot("price-rt-preference-3.2.txt", "price-pref-3.2.eps", 
    "Price vs. PricePreference", "pricePref", "pricePerSecond", 2, 1)
gnuPlot("price-rt-preference-3.2.txt", "perf-pref-3.2.eps", 
    "Queuetime vs. PerfPreference", "perfPref", "queuetime", 4, 3)