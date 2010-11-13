# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require 'rubygems'
require 'trollop'
require File.dirname( __FILE__ ) + '/trace_codec'
require File.dirname( __FILE__ ) + '/set_extensions'

OPTS=Trollop::options do
    opt :file, "Trace DB file to use", :type=>:string, :default=>"ccov-traces.tch"
end

class TraceDB

    def initialize( fname, mode )
        @db=OklahomaMixer.open fname, mode
        raise "Err, unexpected size for SetDB" unless @db.size%3==0
    end

    def traces
        @db.size/3
    end

    def close
        @db.close
    end

    def sample_fraction( f )
        raise ArgumentError, "Fraction between 0 and 1" unless 0<f && f<=1
        cursor=(traces * f)-1
        key_suffixes=@db.keys( :prefix=>"trc:" ).shuffle[0..cursor].map {|e| e.split(':').last}.compact
        hsh={}
        key_suffixes.each {|k|
            hsh[k]={
                :covered=>@db["blk:#{k}"],
                :trace=>@db["trc:#{k}"] #still packed.
            }
            raise "DB screwed?" unless hsh[k][:covered] && hsh[k][:trace]
        }
        hsh
    end

end


module Reductions

    def iterative_reduce( set_hash )
        puts "Starting sample with #{set_hash.size} sets"
        candidates=set_hash.to_a.shuffle
        minset={}
        coverage=Set.new
        # There are two ways into the minset.
        # 1. Add new blocks
        # 2. Consolidate the blocks of 2 or more existing files
        # We're using each here, but the algorithm can be implemented
        # iteratively as traces come in.
        candidates.each {|fn, hsh|
            this_set=Set.unpack( hsh[:trace] )
            # Do we add new blocks?
            unless (this_set_unique=(this_set - coverage)).empty?
                coverage.merge this_set
                # Any old files with unique blocks that
                # this full set covers can be deleted breakeven at worst
                minset.delete_if {|fn, unique_blocks|
                    unique_blocks.subset? this_set
                }
                minset[fn]=this_set_unique
            else
                # Do we consolidate 2 or more sets of unique blocks
                double_covered=minset.select {|fn,unique_blocks|
                    unique_blocks.subset? this_set
                }
                if double_covered.size > 1
                    merged=Set.new
                    double_covered.each {|fn,unique_blocks|
                        merged.merge unique_blocks
                        minset.delete fn
                    }
                    minset[fn]=merged
                end
            end
        }
        [minset, coverage]
    end

    def greedy_reduce( set_hash )
        puts "Starting sample with #{set_hash.size} sets"
        candidates=set_hash.sort_by {|k,v| Integer( v[:covered] ) }
        minset=[]
        coverage=Set.new
        best_fn, best_hsh=candidates.pop
        minset.push best_fn

        # expand the starter set
        best_set=Set.unpack( best_hsh[:trace] )
        coverage=coverage.union( best_set )
        global_coverage=global_coverage.union( best_set )
        puts "Initial best set #{coverage.size} elems"

        # strip elements from the candidates
        # This is outside the loop so we only have to expand
        # the sets to full size once.
        candidates.each {|fn, hsh|
            this_set=Set.unpack( hsh[:trace] )
            hsh[:set]=(this_set - best_set)
        }
        candidates.delete_if {|fn, hsh| hsh[:set].empty? }
        candidates=candidates.sort_by {|fn, hsh| hsh[:set].size }
        best_fn, best_hsh=candidates.pop
        minset.push best_fn
        best_set=best_hsh[:set]
        puts "Next best has #{best_set.size} elems left"
        coverage=coverage.union( best_set )

        # Now start the reduction loop, the Sets are expanded
        puts "Starting reduction"
        until candidates.empty?
            candidates.each {|fn, hsh|
                this_set=hsh[:set]
                hsh[:set]=(this_set - best_set)
            }
            candidates.delete_if {|fn, hsh| hsh[:set].empty? }
            candidates=candidates.sort_by {|fn, hsh| hsh[:set].size }
            best_fn, best_hsh=candidates.pop
            minset.push best_fn
            best_set=best_hsh[:set]
            coverage=coverage.union( best_set )
        end
        [minset, coverage]
    end
end

include Reductions
tdb=TraceDB.new OPTS[:file], "re"
full=tdb.sample_fraction(1)
fraction=0.0625
samples=[]
until fraction > 1 
    samples << tdb.sample_fraction( fraction )
    fraction=fraction*2
end
tdb.close
puts "Collected samples, starting work"
samples.each {|sample|
    puts "FULL: #{full.size} THIS: #{sample.size}"
    mark=Time.now
    minset, coverage=greedy_reduce( sample )
    puts "Greedy: This sample Minset #{minset.size}, covers #{coverage.size}"
    puts "Elapsed: #{Time.now - mark}"
    mark=Time.now
    minset, coverage=greedy_reduce( sample )
    puts "Iterative: This sample Minset #{minset.size}, covers #{coverage.size}"
    puts "Elapsed: #{Time.now - mark}"
}
