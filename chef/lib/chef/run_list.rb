#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2008, 2009 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

class Chef
  class RunList
    include Enumerable

    attr_reader :recipes, :roles, :run_list

    def initialize
      @run_list = Array.new
      @recipes = Array.new
      @roles = Array.new
    end

    def <<(item)
      type, entry, fentry = parse_entry(item)
      case type
      when 'recipe'
        @recipes << entry unless @recipes.include?(entry)
      when 'role'
        @roles << entry unless @roles.include?(entry)
      end
      @run_list << fentry unless @run_list.include?(fentry)
      self
    end

    def ==(*isequal)
      check_array = nil
      if isequal[0].kind_of?(Chef::RunList)
        check_array = isequal[0].run_list
      else
        check_array = isequal.flatten
      end
      
      return false if check_array.length != @run_list.length

      check_array.each_index do |i|
        to_check = check_array[i]
        type, name, fname = parse_entry(to_check)
        return false if @run_list[i] != fname
      end

      true
    end

    def [](pos)
      @run_list[pos]
    end

    def []=(pos, item)
      type, entry, fentry = parse_entry(item)
      @run_list[pos] = fentry 
    end

    def each(&block)
      @run_list.each { |i| block.call(i) }
    end

    def include?(item)
      type, entry, fentry = parse_entry(item)
      @run_list.include?(fentry)
    end

    def reset(*args)
      @run_list = Array.new
      @recipes = Array.new
      @roles = Array.new
      args.flatten.each do |item|
        self << item
      end
      self
    end

    def expand(from_disk=false)
      results = Array.new
      @run_list.each do |entry|
        type, name, fname = parse_entry(entry)
        case type
        when 'recipe'
          results << name unless results.include?(name)
        when 'role'
          role = nil
          if from_disk || Chef::Config[:solo]
            # Load the role from disk
            Chef::Role.from_disk("#{name}")
          else
            # Load the role from the server
            r = Chef::REST.new(Chef::Config[:role_url])
            role = r.get_rest("roles/#{name}")
          end
          role.recipes.each { |r| results <<  r unless results.include?(r) }
        end
      end
      results
    end

    def parse_entry(entry)
      case entry 
      when /^(.+)\[(.+)\]$/
        [ $1, $2, entry ]
      else
        [ 'recipe', entry, "recipe[#{entry}]" ]
      end
    end

  end
end

