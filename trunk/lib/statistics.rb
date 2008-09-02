# This file is part of the calana grid workload generator.
# (c) 2008 Mathias Dalheimer, md@gonium.net
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

class Range
  attr_accessor :min, :max
  def initialize(min=0.0, max=1.0)
    @min=min; @max=max;
  end
  def to_s
    "[#{@min}, #{@max}]"
  end
end

class RejectionException < StandardError
end

# A simple function that dumps the given array of values to
# a file in the global temp directory -> this is for debugging
def dumpRTable(values, filename)
  filename = File.join(ENV["HOME"], "tmp", filename);
  puts "Dumping values to #{filename}"
  File.open(filename, "w") {|file|
    file.puts("index\tvalue")
    values.each_index{|index|
      file.puts("#{index}\t#{values[index]}")
    }
  }
end

# Enhance Array: Allow it to shuffle its contents randomly.
class Array
  def shuffle
    sort_by { rand }
  end

  def shuffle!
    self.replace shuffle
  end
end

# Implements the MC approach - takes a block that checks if x < pdf(y).
def generateMCRandoms(amount)
  if not block_given?
    raise "No probability density function check given - aborting"
  end
  values = Array.new
  while values.size() < amount
    u1=rand()
    u2=rand()
    begin
      distvalue = yield(u1, u2)
      values << distvalue
    rescue RejectionException 
      # do nothing here, just don't add distvalue
    end
  end
  return values
end

# Used for generating randoms for the user preference setting. 
# uses the composition method to multiplex two gaussian distributions.
# TODO: Eliminate outliers before merging and scaling - see Walsh test,
# http://www.statistics4u.info/fundstat_germ/ee_walsh_outliertest.html
def generateDoubleGaussianRandoms(amount)
  range=Range.new(0,1)
  leftvalues=generateGaussianRandoms(amount/2,mean=0.1,sd=0.1)
  rightvalues=generateGaussianRandoms(amount/2,mean=0.9,sd=0.1)
  values= (leftvalues + rightvalues)
  # We need to shuffle the randoms - otherwise, the two arrays would 
  # maintain their structure, which is not desired.
  values.shuffle!
  return linearTransformation(values, range)
end

# Use rejection method to filter uniform randoms such that they 
# fit the gaussian distribution. See Raj Jain, "The Art of Computer
# Systems Performance Analysis", p. 494.
def generateGaussianRandoms(amount, mean=0.0, sd=1.0, range=nil)
  rawvalues = generateMCRandoms(amount) {|u1, u2|
    x = - Math.log(u1)
    y = Math.exp((-(x-1)**2)/2)
    if (u2 > y)
      raise RejectionException, "Not acceptable random number."
    else
      u3=rand()
      if (u3>0.5)
        mean+sd*x
      else
        mean-sd*x
      end
    end
  }
  if range != nil
    return linearTransformation(rawvalues, range)
  else
    return rawvalues
  end
end

# Generate randoms from a gamma distribution - See Raj Jain, "The Art of
# Computer Systems Performance Analysis", p. 490. See also M. Lublins
# Workload Generator.
def generateGammaRandoms(amount, scale=1, shape=1, range=nil)
  a=scale; b=shape;
  if not a>0 and b>0
    raise RejectionException("Invalid parameterization: a=#{a}, b=#{b}")
  end
  if (shape.integer?)
    rawvalues=generateGammaRandomsIntShape(amount, a, b)
  elsif (shape<1)
    rawvalues=generateGammaRandomsShapeSmallerOne(amount, a, b)
  else 
    # Combine the distributions for non-integer shape
    leftvalues = generateGammaRandomsIntShape(amount/2, scale, shape.floor())
    rightvalues = generateGammaRandomsIntShape(amount/2, scale, (shape - shape.floor()))
    rawvalues= (leftvalues + rightvalues)
    rawvalues.shuffle!
  end
  if range != nil
    return linearTransformation(rawvalues, range)
  else
    return rawvalues
  end
end

# Helper method, see generateGammaRandoms
def generateGammaRandomsIntShape(amount, scale, shape)
  rawvalues=Array.new()
  amount.downto(0) {
    uniforms=generateUniformRandoms(shape)
    product=uniforms.inject(1) {|product, n|
      product * n
    }
    rawvalues << -scale*Math.log(product)
  }
  return rawvalues
end

# Helper method, see generateGammaRandoms
def generateGammaRandomsShapeSmallerOne(amount, scale, shape)
  exponentials=generateExponentialRandoms(amount, varlambda=1)
  betas=generateBetaRandoms(amount, shape, 1-shape)
  values=Array.new
  for i in (0..amount)
    value=scale * exponentials[i] * betas[i]
    values << value
  end
  return values
end

# Helper method, see generateGammaRandoms
def generateBetaRandoms(amount, alpha, beta)
  if not alpha>0 and beta>0
    raise RejectionException("Invalid parameterization: a=#{alpha}, b=#{beta}")
  end
  if not alpha<1 and beta<1
    raise RejectionException("Invalid parameter for this implementation: a=#{alpha}, b=#{beta}")
  end
  values=Array.new
  u1=u2=x=y=0.0
  amount.downto(0) {
    begin
      u1=rand()
      u2=rand()
      x=u1.to_f ** (1/alpha.to_f)
      y=u2.to_f ** (1/beta.to_f)
    end while (x+y > 1)
    values << (x/(x+y))
  }
  return values
end

def generateExp2Randoms(amount, lowerbound=0, upperbound=8)
  max=log2(upperbound)
  min=log2(lowerbound)
  if (max % 1) != 0 or (min % 1) != 0
    raise RejectionException("Invalid parameterization: upperbound (#{upperbound}) or lowerbound (#{lowerbound} is not a power2-number!")
  end
  rawvalues=generateUniformRandoms(amount);
  scaledvalues = linearTransformation(rawvalues, Range.new(min, max))
  scaledvalues.map!{|u|
    2**(u.round())
  }
  return scaledvalues
end

# Generate randoms from an exponential distribution using the inversion
# method. 
def generateExponentialRandoms(amount, varlambda=1, range=nil)
  rawvalues=generateUniformRandoms(amount);
  rawvalues.map!{|u|
    -varlambda*Math.log(u)
  }
  if range != nil
    return linearTransformation(rawvalues, range)
  else
    return rawvalues
  end
end

# Scales a set of raw values using linear transformation.
def linearTransformation(rawvalues, range)
  values=Array.new()
  rawmin=rawvalues.min()
  rawmax=rawvalues.max()
  rawvalues.each{|val|
    values << ((range.max - range.min)/(rawmax-rawmin))*(val-rawmin)+range.min
  }
  return values
end

# Calculates the value of the probability density function (PDF)
# for the gaussian distribution for x with the given parameters.
def pdf_gaussian(x, mean, sd)
  return (1/(sd*Math.sqrt(Math::PI*2)))*Math.exp(-((x-mean)**2/(2*sd**2)))
end

# The PDF of the exponential distribution
def pdf_exponential(x, varlambda)
  if (x<0)
    return 0
  else
    return varlambda*Math.exp(-varlambda * x)
  end
end

# Generate simple uniformly distributed random numbers.
def generateUniformRandoms(amount, range=nil)
  values=Array.new
  amount.downto(0) {|index|
    values << rand()
  }
  if range != nil
    return linearTransformation(values, range)
  else
    return values
  end
end

###
## Helper function: Calculate the binary logarithm.
#
def log2(n)
  return (Math.log(n)/Math.log(2))
end

def testSortingAssumption
  numDistr=10
  expCount=1000
  randcollection=Array.new
  sums=Array.new(numDistr*expCount, 0)
  # create numDistr arrays with exponential randoms.
  numDistr.downto(0) {|i|
    exponentials = generateExponentialRandoms(expCount, varlambda=1, range=Range.new(0,100))
    randcollection  = randcollection + exponentials
  }
  (1..10).each{|offset|
    # now, sum stuff up.
    lower=(offset-1)*expCount
    upper=(offset)*expCount
    puts "Summing [#{lower}:#{upper}]"
    (lower..upper).each {|i|
      if i!=0 
        sums[i]=sums[i-1]+randcollection[i];
      end
    }
  }
    #sums.sort!
  dumpRTable(sums, "testsorting.txt");
end

if __FILE__ == $0 
  $verbose = true
  amount=10000
  uniforms=generateUniformRandoms(amount);
  dumpRTable(uniforms, "uniform.txt");
  gaussians=generateGaussianRandoms(amount, mean=0.0, sd=1, range=Range.new(-10.0, 10.0));
  dumpRTable(gaussians, "gaussians.txt");
  rawgaussians=generateGaussianRandoms(amount, mean=0.0, sd=1); 
  dumpRTable(rawgaussians, "rawgaussians.txt");
  doublegaussians=generateDoubleGaussianRandoms(amount);
  dumpRTable(doublegaussians, "doublegaussians.txt");
  exponentials=generateExponentialRandoms(amount, varlambda=1, range=Range.new(0,100));
  dumpRTable(exponentials, "exponentials.txt");
  gammas=generateGammaRandoms(amount, scale=4, shape=2);
  dumpRTable(gammas, "gammas.txt");
  betas=generateBetaRandoms(amount, alpha=0.5, beta=0.5);
  dumpRTable(betas, "betas.txt");
  exp2s=generateExp2Randoms(amount, lowerbound=1, upperbound=32);
  dumpRTable(exp2s, "exp2s.txt");
  testSortingAssumption();
end
