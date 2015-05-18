module CaOpenldap
  class GlobalConfigOptions

    attr_reader :options

    def initialize(path="/etc/openldap/slapd.d/cn=config.ldif")
      @path = path

      content = File.read(path).split(/\n/)
      olc_lines = content.grep /^olc/
      @options = olc_lines.inject({}) do |hash, line|
        insert_option_to_hash(hash, line)
      end
    end

    def set(name, value)
      @options[name.strip] = value.strip
    end

    def delete(name)
      @options.delete name
    end

    def save
      updated = "#{@path}.new"
      current = {}

      File.open(updated, "w") do |output|
        File.read(@path).split(/\n/).each do |line|

          # Output options just before the structuralObjectClass line.
          if line.start_with? 'structuralObjectClass'
            @options.each do |k, v|
              output.puts "#{k.strip}: #{v.strip}"
            end
          end

          # if current line does not define an option
          # outputs it.
          if ! line.start_with? "olc"
            output.puts line
          else
            insert_option_to_hash(current, line)
          end
        end
      end

      File.rename(updated, @path)

      # return true if changes detected.
      @options != current
    end

    def number_of_options
      @options.size
    end

    private 

    def insert_option_to_hash(hash, line)
      k, v = line.split(':')
      hash[k.strip] = v.strip
      hash
    end

  end
end
