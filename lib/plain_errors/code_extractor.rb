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

        result = []
        (start_line..end_line).each do |line_num|
          line_content = lines[line_num - 1].chomp
          marker = line_num == @error_line ? ">>> " : "    "
          result << "#{marker}#{line_num.to_s.rjust(3)}: #{line_content}"
        end

        result
      rescue => e
        ["Error reading source file: #{e.message}"]
      end
    end
  end
end