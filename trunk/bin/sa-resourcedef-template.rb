# This file is to be included by the sa-scheduler.rb script. It defines
# the resources to be used in the scheduling process.

# This is called from the sa-scheduler.rb script. The nodes parameter
# describe the number of nodes to be in the system.
def generateResourceSet(nodes)
  return singleNodeResourceSet(nodes)
end
def singleNodeResourceSet(nodes)
  resourceSet=Array.new
  1.upto(nodes) {|i|
    constantPricing=ConstantPricingStructure.new(0.1)
    puts "Generating resource no. #{i}"
    resource=Resource.new("Resource-"+i.to_s, constantPricing)
    resourceSet.push(resource)
  }
  return resourceSet
end


