#!/usr/bin/env ruby
#~~~~~~~ evo_arithematic.rb ~~~~~~~~
#Using Genetic Algorithms to Solve Arithematic Problems!
#....................................
#Nemesis Fixx (joewillrich@gmail.com)
#....................................
#
require 'optparse'
options = {}

optparse = OptionParser.new { |opts|
    s = 50
    opts.banner = "*"*s\
        + "\r\nEVOLUTIONAL ARITHETIC LEARNER"\
        + "\r\nWritten by Nemesis Fixx (nemesisfixxed@gmail.com)"\
        + "\r\n" << "*"*s << "\r\n"\
        + "Usage: evo_arithematic.rb [options]"
    options[:verbose] = false
    opts.on( '-v', '--verbose', 'Output more information' ) { options[:verbose] = true }
    options[:maxgen] = 100
    opts.on( '-g', '--maxgen MAX_GENERATIONS', 'Maximum number of Generations (default:100)' ) {|v| options[:maxgen] = v.to_i }
    options[:popsize] = 100
    opts.on( '-p', '--popsize POPULATION_SIZE', 'Size of each Population (default:100)' ) {|v| options[:popsize] = v.to_i }
    options[:target] = 100.0
    opts.on( '-t', '--target TARGET', 'The value the system must learn to solve (default:100.0)' ) {|v| options[:target] = v.to_f }
    options[:error] = 0.0
    opts.on( '-e', '--error MAX_ALLOWED_ERROR', 'The maximum amount of error allowed (default:0.0)' ) {|v| options[:error] = v.to_f }
    options[:chromsize] = 8
    opts.on( '-c', '--chromsize CHROMOSOME_SIZE', 'The size of each chromosome (default:8)' ) {|v| options[:chromsize] = v.to_i }
    options[:mutation] = 0.001
    opts.on( '-m', '--mutation MUTATION_RATE', 'The rate at which mutation should occur in a chromosome (default:0.001)' ) {|v| options[:mutation] = v.to_f }
    options[:crossover] = 0.7
    opts.on( '-x', '--crossover CROSSOVER_RATE', 'The rate at which crossover (reproduction) should occur in the population (default:0.7)' ) {|v| options[:crossover] = v.to_f }
    opts.on( '-h', '--help', 'Display this screen' ) { puts opts; exit }
}

#parse out options...
optparse.parse!

GENE_SIZE = 4
CHROMOSOME_SIZE = options[:chromsize]
MUTATION_RATE = options[:mutation]
CROSSOVER_RATE = options[:crossover]
TARGET = options[:target]
POPULATION_SIZE = options[:popsize]
MAX_GENERATION = options[:maxgen]

class Chromosome
    attr_accessor :chromosome, :fitness, :decoded
    def initialize(chromosome=nil)
        @chromosome = chromosome.nil? ? random_chromosome : chromosome
        @decoded = decode(@chromosome)
        @fitness = get_fitness(@decoded)
    end

    def random_chromosome
        #the digits and the 'basic' arithmetic operators
        @@alphabet = (0..9).map{|i|i.to_s} + ['+','-','*','/']
        #mapping the alphabet elements onto their binary representation
        @@encoding = @@alphabet.each_with_index.map{|i,v| 
            [i,v.to_s(2).rjust(4,"0")]
        }.inject({}){|d,v|
            d.update({v[0]=>v[1]}) 
        }
        0.upto(CHROMOSOME_SIZE).map{ 
            @@encoding[@@alphabet[rand(@@alphabet.length)]] 
        }.join
    end

    def decode(chromosome)
        chromosome.scan(/.{1,#{GENE_SIZE}}/).map{|gene| 
            @@encoding.invert[gene] if @@encoding.value?gene 
        }.join\
            .gsub(/(^[^\d]+)|([^\d]+$)/,"")\
            .gsub(/([^\d])([^\d]+)/,"\\1")\
            .gsub(/0+([1-9]+)/,"\\1")\
            .gsub(/(\/[0]+)([^\d]*)/,"\\2")\
            .gsub(/([^\d]*)([1-9]+)([^\d]*)/,"\\1\\2.0\\3")
    end

    def get_fitness(decoded_chromosome)
        res = eval(decoded_chromosome)
        diff = (TARGET - res.to_f).abs
        1 - (diff*1.0/TARGET)
    end

    def crossover(partner_chromosome)
        #get random split point
        split_point = rand(CHROMOSOME_SIZE/2)
        (
            (@chromosome.scan(/.{1,#{GENE_SIZE}}/))[0...split_point] + 
            (partner_chromosome.scan(/.{1,#{GENE_SIZE}}/))[split_point...CHROMOSOME_SIZE]
        ).join
    end

    def mutate
        @chromosome.split(//).map{|b| ( rand <= MUTATION_RATE ) ? ((b=~/^0$/).nil? ? "1" : "0") : b }.join
    end
end


#create a random inital population
population = 0.upto(POPULATION_SIZE).map{ Chromosome.new }
best_chromosome = nil
evolved_generations = 0

for generation in 0...MAX_GENERATION
    #sort population based on fitness, select only upper half (the elite)
    elite = population.sort_by{|a| a.fitness }
    elite = elite[(POPULATION_SIZE/2)...POPULATION_SIZE]
    best_chromosome = elite[-1]
    if (generation + 1) < MAX_GENERATION :
        #randomly breed from the elite a new young breed
        young_generation = elite.shuffle.collect{|e| 
            ( rand <= CROSSOVER_RATE ) ? Chromosome.new(e.crossover(elite[rand(elite.index(e)).floor].chromosome)) : Chromosome.new(e.mutate) 
        }
        population = elite + young_generation
    end
    evolved_generations += 1
    if options[:verbose]
        puts "Generation : #{evolved_generations} | Fitness : #{"%.2f%%" % (best_chromosome.fitness*100)} | Best Chromosome : #{best_chromosome.decoded} "
    end
    #stop if best solution has been found
    break if ((1.0 - best_chromosome.fitness) <= options[:error])
end

puts "After #{evolved_generations}/#{MAX_GENERATION} Generations, Population Size #{POPULATION_SIZE}, Targeting #{TARGET}, we have..."
if not best_chromosome.nil?
    c = best_chromosome
    puts ["BEST Chromosome : #{c.chromosome}","Decoded : #{c.decoded}","Value : %.3f"%eval(c.decoded),"Fitness : %.2f%%" % (c.fitness*100)].join("\r\n")
else
    puts "There's no best chromosome!"
end
