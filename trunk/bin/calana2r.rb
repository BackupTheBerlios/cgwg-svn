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

# Constants for context of the job description...
SEQUENCE = 1;
COALLOCATION = 2;

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
            opts.on("-i", "--input FILE", "the input file in calanasim format") do |inFile|
                options.infile=inFile
            end
            opts.on("-o", "--output directory","the output directory for the report files") do |outdir|
                options.outdir=outdir
            end
            opts.on("-l", "--load FLOAT", "the load level of the run") do |load|
                options.load = load
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
## Job abstraction class
#
class Job
    attr_accessor :type, :responseTime, :jid, :price, :pricePref,
            :perfPref, :runTime
    def initialize(jid)
        @jid=jid
    end
end

###
## A report that prints the Load vs. ART table
#
class LoadARTReport
    def initialize(directory, load)
        reportFileName = directory+"/load-ART.txt"
        @load = load
        if (File.exists?("reportFileName"))
            @reportFile = File.new(reportFileName, "a")
        else
            @reportFile = File.new(reportFileName, "w")
            @reportFile.puts("load\tART")
        end
        @cumulativeResponseTime = 0.0
        @jobCounter = 0
    end
    
    def addJob(job)
        @cumulativeResponseTime += job.responseTime.to_f 
        @jobCounter += 1
    end
    
    def finalize()
        art = (@cumulativeResponseTime.to_f / @jobCounter.to_f)
        @reportFile.puts("#{@load}\t#{art}")
        @reportFile.close
    end
end

###
## A report that prints the Load vs. Price table
#
class LoadAvgPriceReport
    def initialize(directory, load)
        reportFileName = directory+"/load-avgprice.txt"
        @load = load
        if (File.exists?("reportFileName"))
            @reportFile = File.new(reportFileName, "a")
        else
            @reportFile = File.new(reportFileName, "w")
            @reportFile.puts("load\tavgprice")
        end
        @cumulativePrice = 0.0
        @jobCounter = 0
    end
    
    def addJob(job)
        @cumulativePrice += job.price.to_f 
        @jobCounter += 1
    end
    
    def finalize()
        avgprice = (@cumulativePrice.to_f / @jobCounter.to_f)
        @reportFile.puts("#{@load}\t#{avgprice}")
        @reportFile.close
    end
end

###
## A report that prints the price vs. pricePreference and rt vs. perfPref data
#
class PriceRTPrefReport
    def initialize(directory, load)
        @load = load
        reportFileName = directory+"/price-rt-preference-"+load+".txt"
        if (File.exists?("reportFileName"))
            @reportFile = File.new(reportFileName, "a")
        else
            @reportFile = File.new(reportFileName, "w")
            @reportFile.puts("pricePerSecond\tpricePref\tresponseTime\tperfPref")
        end
    end
    
    def addJob(job)
        pricePerSecond = job.price.to_f / job.runTime.to_f
        @reportFile.puts("#{pricePerSecond}\t#{job.pricePref}\t"+
            "#{job.responseTime}\t#{job.perfPref}")
    end
    
    def finalize()
        avgprice = (@cumulativePrice.to_f / @jobCounter.to_f)
        @reportFile.puts("#{@load}\t#{avgprice}")
        @reportFile.close
    end
end

class ReportCollection
    def initialize(load)
        @reports = Array.new
        report1 = LoadARTReport.new($outDir, load);
        report2 = LoadAvgPriceReport.new($outDir, load);
        report3 = PriceRTPrefReport.new($outDir, load);
        @reports << report1 << report2 << report3
    end
    
    def addJob(job)
        @reports.each{|report|
            report.addJob(job)
        }
    end
    
    def finalize()
        @reports.each{|report|
            report.finalize();
        }
    end
end

###
## Script begins here
#
print "calanasim to R read.table converter\n"
   
options = Optparser.parse(ARGV)
    
$inFileName = options.infile
$outDir = options.outdir
$load = options.load
$verbose = options.verbose

if $inFileName == nil or $outDir == nil or $load == nil
    print "please read usage note (-h)\n"
    exit
end


inFile=File.new($inFileName, "r")
reports = ReportCollection.new($load);
print "Reading calanasim log and converting.\n"
inExplanation = false;
context = 0;



inFile.each_line {|line|
    # We skip the comments.
    if (line =~ /^;/)
        next 
    end
    # And empty lines.
    if (line =~ /^$/)
        next
    end
    # We need to ignore the three field explanation lines.
    if (line =~ /^=/ and not inExplanation)
        inExplanation=true
        next
    end
    if (inExplanation and line =~ /^=/)
        inExplanation = false
        next
    end
    if (inExplanation)
        next
    end

    ###
    ## Now, we have only the job result lines.
    #
    
    fields=line.split("|")
    
    tid = fields[0].strip!
    type = fields[1].strip!
    if (tid =~ /^task-/)
        if (type =~ /^sequence/)
            context = SEQUENCE 
        elsif (type =~ /^coallocation/)
            context = COALLOCATION
        end
        next
    end
    
    #puts "Input line: #{line}" if $verbose    
    ###
    ## Read the job description fields
    #
    jid = fields[2].strip!
    jid.sub!("job-", "")
    submitTime = fields[11].strip!
    runTime = fields[14].strip!
    responseTime = fields[16].strip!
    price = fields[17].strip!
    agent = fields[6].strip!
    prefs = fields[7].strip!
    prefFields = prefs.split(";")
    finishtimeField = prefFields[0];
    perfPref = (finishtimeField.split("="))[1]
    pricePrefField = prefFields[1];
    pricePref = (pricePrefField.split("="))[1]
    #puts "perfPref = #{perfPref}, pricePref = #{pricePref}"
    
    ###
    ## Create a job instance
    #
    j = Job.new(jid)
    j.price = price
    j.pricePref = pricePref
    j.perfPref = perfPref
    j.responseTime = responseTime
    j.runTime = runTime
        
    if (context == SEQUENCE)
        puts "SEQUENCE: #{jid} #{submitTime} #{responseTime} #{price}" if $verbose
        j.type=SEQUENCE
    elsif (context == COALLOCATION)
        puts "COALLOCATION: #{jid} #{submitTime} #{responseTime} #{price}" if $verbose
        j.type=COALLOCATION
    end
    
    reports.addJob(j)
}

reports.finalize()
inFile.close()
