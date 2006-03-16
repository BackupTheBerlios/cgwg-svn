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

require 'lib/Workload'
require 'lib/Helpers'
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
            opts.banner = "Usage: swf2r.rb [options]"
            opts.separator ""
            opts.separator "Specific options:"
            # Mandatory argument.
            opts.on("-i", "--input FILE", "the input file in SWF format") do |inFile|
                options.infile=inFile
            end
            opts.on("-o", "--output FILE","the output file for simple R read.table format") do |outFile|
                options.outfile=outFile
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
## Script begins here
#
print "SWF to R read.table converter\n"
   
options = Optparser.parse(ARGV)
    
$inFileName = options.infile
$outFileName = options.outfile
$verbose = options.verbose

if $inFileName == nil or $outFileName == nil
    print "please read usage note (-h)\n"
    exit
end

outFile=File.new($outFileName, "w")
inFile=File.new($inFileName, "r")
outFile.puts("\tsubmitTime\tqueueTime\trunTime\tnodes\twalltime")
print "Reading SWF log and converting.\n"
inFile.each_line {|line|
    if (line =~ /^;/)
      next # We skip the comments.
    end
    fields=line.split()
    id = fields[0]
    submitTime = fields[1]
    queueTime = fields[2]
    runTime = fields[3]
    nodes = fields[4]
    wallTime = [8]
    outFile.puts("#{id}\t#{submitTime}\t#{queueTime}\t#{runTime}\t" + 
      "#{nodes}\t#{wallTime}")
}

outFile.close()
inFile.close()
