require "tempfile"
require "optparse"
require "ostruct"

R_CMD = "Rscript --vanilla"

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
      opts.banner = "Usage: buildAgentsInPaes.rb [options]"
      opts.separator ""
      opts.separator "Specific options:"
      # Mandatory argument.
      opts.on("-i", "--input file", "the path to paes 'absolute-results.txt'") do |infile|
        options.infile=infile
      end
      opts.on("-o", "--output file", "the output filename") do |outfile|
        options.outfile=outfile
      end
      opts.on("-b", "--basepath string", "base path (part before agent names)") do |basePath|
        options.basePath=basePath
      end
      opts.on("-a", "--agents string", "comma separated list of agent names") do |agents|
        options.agents=agents
      end
      opts.on("-p", "--agent-name-positions string", "comma separated list of integers [1:4]") do |pos|
        options.pos=pos
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

options = Optparser.parse(ARGV)

inFile = options.infile
outFile = options.outfile
agents = options.agents
basePath = options.basePath
pos = options.pos

# Checking for required fields
if(inFile == nil or outFile == nil or agents == nil or basePath == nil)
  puts "Please specify base path (-b), input (-i) file, agents (-a) and agent positions (-p)"
  exit
end

# Preparing data, setting defaults
outFile = "out" if outFile == nil
agents = (agents.split(",").map {|x| x = "'" + x + "'"})
if (pos == nil)
  pos = Array.new(agents.size, 1)
else
  pos = (pos.split(",").map {|x| x = "'" + x + "'"})
end

# Sanity check
if (agents.size != pos.size)
  puts "Number of agents and agent positions differ"
  exit
end

# Start with actual work
cmd = <<-END_OF_FILE
printText <- function(coords) {
  text(as.integer(coords[2])-as.integer(coords[2])/10, as.integer(coords[3]), coords[1], pos=coords[4])
}

addAgents <- function(baseList, agentNames, pos) {
  base <- baseList
  labs <- NULL

  i <- 1
  for(n in agentNames) {
    tmp <- read.table(paste("#{basePath}", n, "/analysis/rtable-1.00773044640403.txt", sep=""), head=T)
    price <- sum(tmp$price)
    qtime <- sum(tmp$qtime)
    labs <- rbind(labs, c(n, qtime, price, pos[i]))
    nextField <- length(base[,1]) + 1
    base[nextField,] <- c(qtime, price)
    i <- i+1
  }

  setEPS()
  postscript("#{outFile}.eps")

  plot(base, log="xy")  
  apply(labs, 1, printText)
}

list <- read.table("#{inFile}", head=T)
addAgents(list, c(#{agents.join(", ")}), c(#{pos.join(", ")}))
END_OF_FILE

cmdfile = Tempfile.new("r-cmd")
cmdfile.print(cmd)
cmdfile.close

`#{R_CMD} #{cmdfile.path}`
