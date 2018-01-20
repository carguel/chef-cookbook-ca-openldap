module CaOpenldap
  class GlobalConfigOptions

    attr_reader :options

    def initialize(path="/etc/openldap/slapd.d/cn=config.ldif")
      @path = path

      content = read_lines_from_file @path

      olc_lines = content.grep(/^olc/)
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

        content = read_lines_from_file @path
        content.each do |line|

          # Remove CRC comment
          next if line.start_with? '# CRC'

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

      # Update the file content while preserving its UID/GID
      old_file_stats = File.stat(@path)
      File.rename(updated, @path)
      FileUtils.chown(old_file_stats.uid, old_file_stats.gid, @path)

      # return true if changes detected.
      @options != current
    end

    def number_of_options
      @options.size
    end

    private 

    def insert_option_to_hash(hash, line)
      k, v = line.split(':', 2)
      hash[k.strip] = v.strip
      hash
    end

    # Read lines from slapd config file, joining
    # multi-line definitions as single-ligne definitions.
    # @param [Array<String>] List of lines found in config file.
    def read_lines_from_file(file_path)
      full_content = File.read(file_path)

      # join multi-lines
      full_content.gsub!(/\n /, "")

      # Split lines
      full_content.split(/\n/)
    end

  end
end
