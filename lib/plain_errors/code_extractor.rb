module PlainErrors
  class CodeExtractor
    def initialize(file_path, error_line)
      @file_path = file_path
      @error_line = error_line
    end

    def extract(context_lines = 3)
      return ["Source file not found: #{@file_path}"] unless File.exist?(@file_path)

      begin
        lines = File.readlines(@file_path)
        start_line = [@error_line - context_lines, 1].max
        end_line = [@error_line + context_lines, lines.length].min

        # Calculate width for line number padding
        max_line_num = end_line
        line_num_width = max_line_num.to_s.length

        result = []
        (start_line..end_line).each do |line_num|
          line_content = lines[line_num - 1].chomp
          formatted_num = line_num.to_s.rjust(line_num_width)
          # Don't add space after colon for blank lines
          if line_content.empty?
            result << "#{formatted_num}:"
          else
            result << "#{formatted_num}: #{line_content}"
          end
        end

        # Strip blank/whitespace-only lines from beginning and end
        result = strip_blank_lines(result)

        result
      rescue => e
        ["Error reading source file: #{e.message}"]
      end
    end

    private

    def strip_blank_lines(lines)
      # Remove blank lines from the beginning
      lines = lines.drop_while { |line| line.match?(/^\d+:\s*$/) }

      # Remove blank lines from the end
      lines = lines.reverse.drop_while { |line| line.match?(/^\d+:\s*$/) }.reverse

      lines
    end
  end
end