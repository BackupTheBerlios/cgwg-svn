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
            opts.banner = "Usage: PBSLog-Parser.rb [options]"
            opts.separator ""
            opts.separator "Specific options:"
            # Mandatory argument.
            opts.on("-i", "--input FILE", "the input file in PBS format") do |inFile|
                options.infile=inFile
            end
            opts.on("-o", "--output FILE","the output file for SWF format") do |outFile|
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
print "PBS log file to SWF converter\n"
   
options = Optparser.parse(ARGV)
    
clusterConfig=ClusterConfig.new("virgo.itwm.fhg.de", 72, 1, 0)

$inFileName = options.infile
$outFileName = options.outfile
$verbose = options.verbose

if $inFileName == nil or $outFileName == nil
    print "please read usage note (-h)\n"
    exit
end

workload=Workload.new(clusterConfig)
inFile=File.new($inFileName, "r")
jobID=1
print "Reading PBS log\n"
inFile.each_line {|line|
    validRecord = true
    fields=line.split(";")
    # E indicates an end of record entry, all information
    # is collected here.
    if (fields[1] =~ /E/) 
        # we found a job information field, which we need to parse
        jobInfo = fields[3]
        #print jobInfo
        print "Extracting job record & creating job instance...\n" if $verbose
        job=AtomicJob.new()
        job.jobID=jobID
        startTime = 0
        jobProperties = jobInfo.split(" ")
        jobProperties.each{|prop|
            id, value = prop.split("=")
            case id
            when /qtime/
                # The job was submitted in the pbs queue
                print "\n\tSubmittime: #{value}" if $verbose
                job.submitTime = value.to_i
            when /start/
                startTime = value.to_i
                print "\n\tStarttime: #{startTime-job.submitTime}" if $verbose
                job.waitTime = startTime - job.submitTime
                if job.waitTime < 0
                    validRecord = false
                    print "\nWARNING: Negative waitTime found"
                    print "\nrunTime = #{job.waitTime}" if $verbose
                end
            when /Resource_List.nodect/
                # nodect contains the number of processors PBS assigned to this
                # job.
                print "\n\tnumAllocatedProcessors: #{value}" if $verbose
                job.numberAllocatedProcessors = value.to_i
            when /Resource_List.walltime/
                hour, min, sec = value.split(":")
                walltime=sec.to_i+60*min.to_i+60*60*hour.to_i
                print "\n\twalltime: #{walltime}" if $verbose
                job.wallTime = walltime
            when /end/
                job.runTime = value.to_i - startTime
                if job.runTime < 0
                    validRecord = false
                    print "\nWARNING: Negative runTime found"
                    print "\nrunTime = #{job.runTime}" if $verbose
                end
                print "\n\truntime: #{job.runTime}" if $verbose
            when /Exit_status/
                # Unfortunately, the exit code has a user-defined meaning, so we
                # do not include it in the SWF. See also:
                # http://www.supercluster.org/pipermail/torqueusers/2006-January/002942.html
                print "\n\texit code: #{value}" if $verbose
            when /resources_used.walltime/
                print "\n\tused walltime: #{value}" if $verbose
            end
        }
        jobID+=1;
        if validRecord
          workload.addJob(job)
        else
          print "\nWARNING: Skipping invalid record"
        end
    end
}
inFile.close()

minSubmitTime = nil
print "Normalizing job submission times\n"
workload.eachJob{|job|
    ###
    ## The first element should contain the minimal submission
    ## time.
    #
    if minSubmitTime == nil
        minSubmitTime = job.submitTime
    end
    job.submitTime = job.submitTime - minSubmitTime
}

print "Writing SWF file\n"
outFile=File.new($outFileName, "w")
outFile.puts(clusterConfig.writeSWFFormat())
workload.eachJob{|job|
    outFile.puts(job.writeSWFFormat())
}
outFile.close()