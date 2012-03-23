#!/usr/bin/env ruby
#~~~~~~~ evo_arithematic.rb ~~~~~~~~
#Using Genetic Algorithms to Solve Schedulling Problems!
#....................................
#Nemesis Fixx (joewillrich@gmail.com)
#....................................
#
require 'optparse'
options = {}

optparse = OptionParser.new { |opts|
    s = 50
    opts.banner = "*"*s\
        + "\r\nEVOLUTIONAL SCHEDULING LEARNER"\
        + "\r\nWritten by Nemesis Fixx (nemesisfixxed@gmail.com)"\
        + "\r\n" << "*"*s << "\r\n"\
        + "Usage: evo_schedule.rb [options]"
    options[:verbose] = 0
    opts.on( '-v', '--verbose VERBOSE_LEVEL', 'Output more information | default : 0' ) {|v| options[:verbose] = v.to_i }
    options[:maxgen] = 100
    opts.on( '-g', '--maxgen MAX_GENERATIONS', 'Maximum number of Generations | default : 100' ) {|v| options[:maxgen] = v.to_i }
    options[:task_spec] = "A(1:1:1:4),B(2:1:2:3)"
    opts.on( '-s', '--task_spec TASK_SPECIFICATION', "Task Specification as label(task_duration:min_chuck_duration:priority:reward) | default : #{options[:task_spec]}" ) {|v| options[:task_spec] = v.to_s }
    options[:popsize] = 100
    opts.on( '-p', '--popsize POPULATION_SIZE', 'Size of each Population | default : 100' ) {|v| options[:popsize] = v.to_i }
    options[:dependecies] = nil
    opts.on( '-d', '--deps DEPENDECIES', 'Any Dependencies in the form A->B,C->D,.. | default : none' ) {|v| options[:dependecies] = v.to_s }
    options[:chromsize] = nil
    opts.on( '-c', '--chromsize CHROMOSOME_SIZE', 'The size of each chromosome | default : total of task durations' ) {|v| options[:chromsize] = v.to_i }
    options[:time] = nil
    opts.on( '-t', '--time TIME_AVAILABLE', 'The total time available | default : CHROMOSOME_SIZE' ) {|v| options[:time] = v.to_i }
    options[:mutation] = 0.001
    opts.on( '-m', '--mutation MUTATION_RATE', 'The rate at which mutation should occur in a chromosome | default : 0.001' ) {|v| options[:mutation] = v.to_f }
    options[:crossover] = 0.7
    opts.on( '-x', '--crossover CROSSOVER_RATE', 'The rate at which crossover (reproduction) should occur in the population | default : 0.7' ) {|v| options[:crossover] = v.to_f }
    options[:error] = 0.0
    opts.on( '-e', '--error MAX_ALLOWED_ERROR', 'The maximum amount of error allowed (default:0.0)' ) {|v| options[:error] = v.to_f }
    opts.on( '-h', '--help', 'Display this screen' ) { puts opts; exit }
}

#parse out options...
optparse.parse!

tasks = options[:task_spec]

def parse_tasks(task_str)
    task_dic = {}
    task_str.split(/,/).collect{|t|
        label = t[/^[^(]+/]
        params = t[/\(.+\)/][/[\d:]+/].split(/:/)
        task_dic[label] = {:label => label, :time => params[0].to_i,:chunk_time => params[1].to_i, :priority => params[2].to_i, :reward => params[3].to_f }
        d = task_dic[label]
        d[:chunk_time] = d[:time] if d[:chunk_time] > d[:time]
    }
    task_dic
end

def parse_dependecies(deps)
    #we shall create a dictionary where the keys are the dependant symbols
    #and the values are the symbols that they depend on
    dic = {}
    deps.split(/,/).collect{|d|
        if d=~/[^ ]+[ ]*->[ ]*[^ ]+/
            rule = d.split(/->/)
            before,after = rule[0].strip,rule[1].strip
            if dic[after].nil?
                dic[after] = [before]
            else
                dic[after] << before
            end
        end
    }
    dic
end


def get_combined_task_duration(tasks)
    tasks.values.inject(0){|sum,t| sum + t[:time]}
end

TASKS = parse_tasks(tasks)

the_empty_task = TASKS['-']

TASKS.delete('-')

TOTAL_REQUIRED_TIME = get_combined_task_duration(TASKS) 
#by default, we shall infer the chromosome size to the total combined time for all tasks given
tCHROMOSOME_SIZE = options[:chromsize].nil? ? TOTAL_REQUIRED_TIME : options[:chromsize] 
TIME_AVAILABLE = options[:time].nil? ? tCHROMOSOME_SIZE : options[:time]

#we also shall have a special task called the "empty task" == chill time? that will occupy all 
#available free time :-)
freetime = TIME_AVAILABLE - tCHROMOSOME_SIZE
freetime = freetime >= 0 ? freetime : 0
#use the provided empty task / create a default one
TASKS["-"] = the_empty_task.nil? ? {:label => "-", :time => freetime, :chunk_time => 1, :priority => 0, :reward => 0} : the_empty_task

#re-adjust chromosome size to accomodate the "empty tasks" / free time
CHROMOSOME_SIZE = options[:chromsize].nil? ? get_combined_task_duration(TASKS) : options[:chromsize] 

MUTATION_RATE = options[:mutation]
CROSSOVER_RATE = options[:crossover]
POPULATION_SIZE = options[:popsize]
MAX_GENERATION = options[:maxgen]

ALPHABET = TASKS.keys
#mapping the alphabet elements onto their binary representation
temp = ALPHABET.each_with_index.map{|v,i| 
    [v,i.to_s(2)]
}
GENE_SIZE = temp.max_by{|a| a[1].length }[1].length
ENCODING = temp.map{|a| 
    [a[0],a[1].rjust(GENE_SIZE,"0")]
}.inject({}){|d,v|
    d.update({v[0]=>v[1]}) 
}

#process dependecies if any
deps = nil
if not options[:dependecies].nil?
    deps = parse_dependecies(options[:dependecies])
end
DEPENDECIES = deps

OPTIONS = options

class Chromosome
    attr_accessor :chromosome, :fitness, :decoded
    def initialize(chromosome=nil)
        @chromosome = chromosome.nil? ? random_chromosome : chromosome
        @decoded = decode(@chromosome)
        @fitness = get_fitness(decode(@chromosome,false))
    end

    def random_chromosome
        chrom = []
        while chrom.length < TIME_AVAILABLE
            symbol = TASKS.keys[rand(TASKS.length)]
            #if chrom.count(symbol) < TASKS[symbol][:time]
                chrom << ENCODING[symbol]
            #end
        end
        chrom.join
    end

    def decode(chromosome,join=true)
        dec = chromosome.scan(/.{1,#{GENE_SIZE}}/).map{|gene| 
            ENCODING.invert[gene] if ENCODING.value?gene 
        }
        final = []

        dec.each{|symbol| 
            #check time constraints
            #only add this task, if the previous one is complete!
            if(final.length > 0)
                previous = final[final.length - 1]
                if final.join.scan(Regexp.new("#{previous}+")).last.count(previous) < TASKS[previous][:chunk_time]
                    if symbol != previous
                        #p "Skipping #{symbol} before #{final.join}"
                        next #skip this symbol...
                    end
                end
            end

            #a symbol (apart from the empty task symbol) should'nt appear more times than it ought to
            if (final.count(symbol) < TASKS[symbol][:time])
                #check dependecies if any
                if not DEPENDECIES.nil?
                    if DEPENDECIES[symbol]
                        #ensure that this occurs exactly after itself (only if it's not the first!) or something it depends on
                        is_ok = true
                        if final.length == 0
                            is_ok &= false #a dependant symbol can't come first!
                        else
                            if not DEPENDECIES[symbol].include?final[final.length - 1] 
                                is_ok &= false #a dependant symbol can't come first!
                                #p "#{symbol} Cant come before dependants #{DEPENDECIES[symbol]}"
                            end
                        end

                        if is_ok
                            final << symbol
                        else
                            final << '-'
                        end
                    else #no dependecies
                        final << symbol
                    end
                else #no deps defined
                    final << symbol
                end
            else
                final << '-'
            end
        }
        join ? final.join : final
    end

    def get_fitness(decoded_chromosome_list)
        return 0 if decoded_chromosome_list.class != Array
        #get priority score
        puts "For Chromosome #{decoded_chromosome_list}" if OPTIONS[:verbose] > 2
        priority_score = decoded_chromosome_list.each_with_index.map{|symbol,index|
            (1 - ((index*1.0)/TIME_AVAILABLE)) * TASKS[symbol][:priority] 
        }.inject(0){|sum,t| sum + t}
        puts "Priority Score : #{priority_score}"if OPTIONS[:verbose] > 2
        #reward score
        reward_score = TASKS.keys.inject(0){|sum,symbol| 
            #only give rewards for none empty tasks
            symbol == '-' ? sum : sum + ((decoded_chromosome_list.count(symbol) * 1.0)/TIME_AVAILABLE) * TASKS[symbol][:reward]
        }
        puts "Reward Score : #{reward_score}"if OPTIONS[:verbose] > 2
        #chill-score
        time_given_nonempty_tasks = decoded_chromosome_list.select{|s| s!='-' }.length
        #puts "Time : Available : #{TIME_AVAILABLE}, Required : #{TOTAL_REQUIRED_TIME}, Non-Empty Tasks : #{time_given_nonempty_tasks}"if OPTIONS[:verbose]
        free_time = TIME_AVAILABLE - time_given_nonempty_tasks
        chill_score = decoded_chromosome_list.each_with_index.map{|symbol,index|
            symbol != "-" ?  0 : ((index*1.0)/TIME_AVAILABLE) * (((time_given_nonempty_tasks * 1.0)/TOTAL_REQUIRED_TIME) * TASKS["-"][:reward])
        }.inject(0){|sum,t| sum + t}

        puts "Chill Score : #{chill_score}"if OPTIONS[:verbose] > 2

        #total fitness
        total = priority_score + reward_score + chill_score
        puts "Fitness : #{total}"if OPTIONS[:verbose] > 1
        puts " " * 30 if OPTIONS[:verbose] > 1
        total
    end

    def crossover(partner_chromosome)
        begin
            #get random split point
            split_point = rand(CHROMOSOME_SIZE/2)
            (
                ()[0...split_point] + 
                (partner_chromosome.scan(/.{1,#{GENE_SIZE}}/))[split_point...CHROMOSOME_SIZE]
            ).join
        rescue
            @chromosome
        end
    end

    def mutate
        new = []
        old = @chromosome.scan(/.{1,#{GENE_SIZE}}/)
        while new.length < TIME_AVAILABLE
            if ( rand <= MUTATION_RATE )
                #insert new gene into chromosome
                symbol = TASKS.keys[rand(TASKS.length)]
                new << ENCODING[symbol]
            else
                #use old chromosome
                new << old[new.length - 1]
            end
        end
        new.join
    end
end


if POPULATION_SIZE == 0
    puts "No Population!"
    exit
end

if MAX_GENERATION == 0
    puts "No Generation to Evolve!"
    exit
end

#create a random inital population
population = 0.upto(POPULATION_SIZE - 1).map{ Chromosome.new }
best_chromosome = nil
evolved_generations = 0

best = []
best_deviations = []

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
        #then, mutate the elite!
        #elite = elite.map{|e| Chromosome.new(e.mutate) }
        elite[-1] = Chromosome.new(elite[-1].mutate) 

        #the new better generation
        population = elite + young_generation
    end
    evolved_generations += 1
    if options[:verbose]
        puts "Generation : #{evolved_generations} | Fitness : #{"%.2f" % (best_chromosome.fitness)} | Best Chromosome : #{best_chromosome.decoded} "
    end
    best << best_chromosome.fitness
    #stop if best solution has converged
    if best.length > 0
        deviation = (best[best.length - 1] - best_chromosome.fitness).abs
        if best_deviations.length > (MAX_GENERATION / 4.0)
            mean_dev = (best_deviations.inject(0.0){|sum,v| sum + v} / best_deviations.length)
            max = best.max
            break if ((deviation - mean_dev) < OPTIONS[:error] ) and ( best.count(best_chromosome.fitness) >= best.count(max))
        end

        best_deviations << deviation
    end
end

puts "\r\nFor Task Specification : "
puts "*" * 30
puts "DEPENDENCIES : #{OPTIONS[:dependecies]}" if not OPTIONS[:dependecies].nil?
TASKS.values.map{|t| puts "#{t[:label]}, priority : #{t[:priority]}, reward : #{t[:reward]}, duration : #{t[:time]}, min-chuck duration : #{t[:chunk_time]}" }
puts "*" * 30
puts ""
puts "After #{evolved_generations}/#{MAX_GENERATION} Generations, Population Size #{POPULATION_SIZE}" 
if not best_chromosome.nil?
    c = best_chromosome
    puts ["BEST Chromosome Decoded : #{c.decoded}","Fitness : %.2f" % (c.fitness)].join("\r\n")
else
    puts "There's no best chromosome!"
end
