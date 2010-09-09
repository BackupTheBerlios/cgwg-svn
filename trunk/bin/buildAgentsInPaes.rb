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
      opts.on("-l", "--loadlevel float", "loadlevel") do |loadlevel|
        options.loadlevel=loadlevel
      end
      opts.on("-r", "--restore", "restore saved data") do |restore|
        options.restore=restore
      end
      opts.on("-s", "--save", "save raw data") do |save|
        options.save=save
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
loadlevel = options.loadlevel
save = options.save
restore = options.restore

# Checking for required fields
if((inFile == nil and !restore) or (inFile and restore) or
   (!save and outFile == nil) or
   loadlevel == nil or agents == nil or basePath == nil or pos == nil)
  puts "Following error(s) occoured:"
  puts "  * Non or both flags -i and -r set: use exactly one" if ((inFile == nil and !restore) or (inFile and restore)) 
  puts "  * No output is specified: set at least one of -o or -s" if (!save and outFile == nil)
  puts "  * No loadlevel is set" if loadlevel==nil
  puts "  * No agents specified" if agents==nil
  puts "  * No agent's positions specified" if pos==nil
  puts "  * No basepath  set" if basePath==nil
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

addAgents <- function(base, labs, agentNames, pos) {
  i <- 1
  for(n in agentNames) {
    tmp <- read.table(paste("#{basePath}", n, "/analysis/rtable-#{loadlevel}.txt", sep=""), head=T)
    price <- sum(tmp$price)
    qtime <- sum(tmp$qtime)
    labs <- rbind(labs, c(n, qtime, price, pos[i]))
    nextField <- length(base[,1]) + 1
    base[nextField,] <- c(qtime, price)
    i <- i+1
  }
  ret <- list(base, labs)
}

plotGraph <- function(base, labs, outFile) {
  setEPS()
  postscript(outFile)

  plot(base, log="xy")  
  apply(labs, 1, printText)
}

saveData <- function(base, labs) {
  write.table(base, file="saved_list.txt")
  write.table(labs, file="saved_labels.txt")
}
END_OF_FILE

if(inFile!=nil)
  cmd << <<-END_OF_FILE
list <- read.table("#{inFile}", head=T)
labels <- NULL
END_OF_FILE
elsif(restore)
  cmd << <<-END_OF_FILE
list <- read.table("saved_list.txt", header=T)
labels <- read.table("saved_labels.txt", header=T)
END_OF_FILE
end

cmd << <<-END_OF_FILE
val <- addAgents(list, labels, c(#{agents.join(", ")}), c(#{pos.join(", ")}))
list <- val[[1]]
labels <- val[[2]]
END_OF_FILE

cmd << "saveData(list, labels)\r\n" if save
cmd << "plotGraph(list, labels, '#{outFile}')\r\n" if outFile

cmdfile = Tempfile.new("r-cmd")
cmdfile.print(cmd)
cmdfile.close

`#{R_CMD} #{cmdfile.path}`
