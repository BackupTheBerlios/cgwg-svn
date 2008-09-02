#!/usr/bin/env ruby
# This file is part of the calana grid workload generator.
# (c) 2008 Christian Bischof, christianbischof@gmx.de
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

# Read the CGWG location from the environment, warn otherwise
if (ENV["CGWG_HOME"] == nil)
  puts "WARNING: Environment does not define $CGWG_HOME!"
else
  libpath= File.join(File.expand_path(ENV["CGWG_HOME"]), "lib")
  $:.unshift << libpath
end

require 'optparse'
require 'ostruct'
require 'statistics'

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
            opts.banner = "Usage: experimentGenerator.rb [options]"
            opts.separator ""
            opts.separator "Specific options:"
            # Mandatory argument.
            opts.on("-a", "--agents INT", "number of agents to createa") do |agents|
                options.agents=agents
            end
            opts.on("-c", "--cpus INT", "#cpus (regard cpu-mode)") do |cpus|
                options.cpus=cpus
            end
            opts.on("-d", "--duration INT", "auction duration") do |duration|
                options.duration=duration
            end
            opts.on("-e", "--disable-scoring", "disable scoring") do |s|
                options.disablescoring=s
            end
            opts.on("-f", "--filename STRING","output file name (without .xml)") do |filename|
                options.filename=filename
            end
            opts.on("-i", "--base-price-min FLOAT","min base price") do |basepmin|
                options.basepmin=basepmin 
            end
            opts.on("-j", "--base-price-max FLOAT","max base price") do |basepmax|
                options.basepmax=basepmax 
            end
            opts.on("-k", "--time-price-min FLOAT","min time price") do |timepmin|
                options.timepmin=timepmin 
            end
            opts.on("-l", "--time-price-max FLOAT","max time price") do |timepmax|
                options.timepmax=timepmax 
            end
            opts.on("-m", "--cpu-mode STRING","single (#CPUs = #cpus), pow (#CPUs = 2^n where max(n) = #cpus)") do |cpumode|
                options.cpumode=cpumode 
            end
            opts.on("-n", "--bid-prob-min FLOAT","min bid probability") do |bpmin|
                options.bpmin=bpmin 
            end
            opts.on("-o", "--bid-prob-max FLOAT","max bid probability") do |bpmax|
                options.bpmax=bpmax 
            end
            opts.on("-p", "--reject-prob-min FLOAT","min reject probability") do |rpmin|
                options.rpmin=rpmin 
            end
            opts.on("-q", "--reject-prob-max FLOAT","max reject probability") do |rpmax|
                options.rpmax=rpmax 
            end
            opts.on("-r", "--abort-prob-min FLOAT","min abort probability") do |apmin|
                options.apmin=apmin 
            end
            opts.on("-s", "--abort-prob-max FLOAT","max abort probability") do |apmax|
                options.apmax=apmax 
            end
            opts.on("-t", "--type STRING","broker type (direct, text)") do |brokertype|
                options.brokertype=brokertype 
            end
            opts.on("-v", "--verbose", "Run verbosely") do |v|
                options.verbose = v
            end
            opts.on("-w", "--over-alloc-min FLOAT","min over allocation fee") do |overallocmin|
                options.overallocmin=overallocmin
            end
            opts.on("-x", "--over-alloc-max FLOAT","max over allocation fee") do |overallocmax|
                options.overallocmax=overallocmax
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

# some useful methods

def mda(width, height)
  mda = Array.new(width)
  mda.map! { Array.new(height) }
end

def round(number, decimals)
  (number * 10**decimals).round.to_f / 10**decimals
end

def getCpus
  if @cpuMode == "single"
    return @cpus
  elsif @cpuMode == "pow"
    return 2**rand(@cpus+1)
  end
end

def generateRandomDirect(amount)
  randoms = mda(amount, 3)
  basePrices = generateUniformRandoms(amount, Range.new(@basePriceMin, @basePriceMax))
  timePrices = generateUniformRandoms(amount, Range.new(@timePriceMin, @timePriceMax))
  amount.times {|row|
    randoms[row][0] = round(basePrices[row], 2)
    randoms[row][1] = round(timePrices[row], 2)
    randoms[row][2] = getCpus
  }
  return randoms
end

def generateRandomText(amount)
  randoms = mda(amount, 6)
  basePrices = generateUniformRandoms(amount, Range.new(@basePriceMin, @basePriceMax))
  timePrices = generateUniformRandoms(amount, Range.new(@timePriceMin, @timePriceMax))
  oversizedAllocFee = generateUniformRandoms(amount, Range.new(@overAllocMin, @overAllocMax))
  bidProb = generateUniformRandoms(amount, Range.new(@bidProbabilityMin, @bidProbabilityMax))
  rejectProb = generateUniformRandoms(amount, Range.new(@rejectProbabilityMin, @rejectProbabilityMax))
  abortProb = generateUniformRandoms(amount, Range.new(@abortProbabilityMin, @abortProbabilityMax))
  amount.times {|row|
    randoms[row][0] = round(basePrices[row], 2)
    randoms[row][1] = round(timePrices[row], 2)
    randoms[row][2] = round(oversizedAllocFee[row], 2)
    randoms[row][3] = round(bidProb[row], 2)
    randoms[row][4] = round(rejectProb[row], 2)
    randoms[row][5] = round(abortProb[row], 2)
  }
  return randoms
end

def getHeader #TODO adept
  header = <<-END_OF_HEADER
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE calana:experiment SYSTEM "experiment.dtd">
<calana:experiment name="single-#{@brokerType}" xmlns:calana="http://www.itwm.fhg.de/calana/experiment/">
  <description>
    some experiment
  </description>
  <workload>
    <input format="xml">
      <!-- we use the file from the commandline -->
      <file>some-non-existent-file.xml</file>
    </input>
    <output format="txt">
      <file>-</file>
    </output>
  </workload>
  <cluster name="cluster-1-1">
    <cpus>#{getCpus}</cpus>
    <scheduler type="fcfs"/>
  </cluster>
  <agents topbroker="broker">
    <manager name="workload-manager"/>
END_OF_HEADER
  if @brokerType == "direct"
    header << <<-END_OF_DIRECT_BROKER
    <broker name="broker" class="calana.agents.impl.DirectBroker">
      <cluster-ref name="cluster-1-1"/>
    </broker>
END_OF_DIRECT_BROKER
  else
    header << <<-END_OF_TEXT_BROKER
    <broker name="broker">
      <prop name="auctionDuration" value="#{@duration}"/>
      <prop name="enableScoring" value="#{@scoring}"/>
    </broker>
END_OF_TEXT_BROKER
  end
  return header
end

def getDirectAgents(amount)
  randNum = generateRandomDirect(amount)
  agents = ""
  amount.times {|num|
    agents << <<-END_OF_DIRECT_AGENTS
    <agent name="bidder-#{num+1}" class="calana.agents.impl.BasicBidAgent">
    <cluster-ref name="cluster-1-1"/>
      <prop name="basePrice" value="#{randNum[num][0]}"/>
      <prop name="timePrice" value="#{randNum[num][1]}"/>
      <prop name="cpus" value="#{randNum[num][2]}"/>
    </agent>
END_OF_DIRECT_AGENTS
  }
  return agents
end

def getBiddingAgents(amount)
  randNum = generateRandomText(amount)
  agents = ""
  amount.times {|num|
    agents << <<-END_OF_BID_AGENTS
    <agent name="bidder-#{num+1}" class="calana.agents.impl.BasicBidAgent">
      <cluster-ref name="cluster-1-1"/>
      <prop name="basePrice" value="#{randNum[num][0]}"/>
      <prop name="timePrice" value="#{randNum[num][1]}"/>
      <prop name="oversizedAllocationFee" value="#{randNum[num][2]}"/>
      <prop name="bidProbability" value="#{randNum[num][3]}"/>
      <prop name="rejectProbability" value="#{randNum[num][4]}"/>
      <prop name="abortProbability" value="#{randNum[num][5]}"/>
    </agent>
END_OF_BID_AGENTS
  }
  return agents
end

def getFooter # TODO adept
  footer = <<-END_OF_FOOTER
  </agents>
</calana:experiment>
END_OF_FOOTER
  return footer
end


###
## Script begins here
#
print "Calana Experiment Generator Frontend\n"

options = Optparser.parse(ARGV)

agents = options.agents.to_i
fileName = options.filename
disableScoring = options.disablescoring
@scoring = true
@brokerType = options.brokertype
@verbose = options.verbose
@duration = options.duration.to_i
@cpus = options.cpus.to_i
@cpuMode = options.cpumode
@basePriceMin = options.basepmin.to_f
@basePriceMax = options.basepmax.to_f
@timePriceMin = options.timepmin.to_f
@timePriceMax = options.timepmax.to_f
@bidProbabilityMin = options.bpmin.to_f
@bidProbabilityMax = options.bpmax.to_f
@rejectProbabilityMin = options.rpmin.to_f
@rejectProbabilityMax = options.rpmax.to_f
@abortProbabilityMin = options.apmin.to_f
@abortProbabilityMax = options.apmax.to_f
@overAllocMin = options.overallocmin.to_f
@overAllocMax = options.overallocmax.to_f


# setting defaults
if agents == 0 or (@brokerType != "direct" and @brokerType != "text")
  puts "plase read usage note (-h)\n"
  puts "agents: #{agents}" if @verbose
  puts "brokerType: #{@brokerType}" if @verbose
  exit
end

@scoring = false if disableScoring

if @cpuMode == nil or (@cpuMode != "single" and @cpuMode != "pow")
  @cpuMode = "pow"
  puts "none or wrong CPU-mode: setting to '#{@cpuMode}'"
end
if @duration == 0
  @duration = 100
  puts "no duration set: setting to #{@duration}"
end
if @cpus == 0
  @cpus = 5
  puts "no #cpus set: setting to #{@cpus}"
end
if @basePriceMin == 0
  @basePriceMin = 10
  puts "no basePriceMin set: setting to #{@basePriceMin}"
end
if @basePriceMax == 0
  @basePriceMax = 17
  puts "no basePriceMax set: setting to #{@basePriceMax}"
end
if @timePriceMin == 0
  @timePriceMin = 0.1
  puts "no basePriceMin set: setting to #{@timePriceMin}"
end
if @timePriceMax == 0
  @timePriceMax = 2.0
  puts "no basePriceMax set: setting to #{@timePriceMax}"
end

basedir=File.expand_path(ENV["CGWG_HOME"])
puts "Assuming base directory #{basedir}\n"
puts ""



# generate name if none is provided and append the extension
if fileName == nil
  fileName = "experiment_#{@brokerType}_#{agents}.xml"
else
  fileName = "#{fileName}.xml"
end
fileName = File.expand_path("#{basedir}/var/#{fileName}")
puts "File name: #{fileName}" if @verbose

# check if file exists
if File.exists?(fileName)
  puts "File '#{fileName}' already exists."
  puts "Exiting."
  exit
end



# build file
File.open(fileName, "w") {|handle|
  puts "Generate header ..." if @verbose
  handle.puts getHeader
  puts "Generate agents (#{agents}) ..." if @verbose
  if @brokerType == "direct"
    handle.puts getDirectAgents(agents)
  else
    handle.puts getBiddingAgents(agents)
  end
  puts "Generate footer ..." if @verbose
  handle.puts getFooter
}
puts "file generated: #{fileName}"
