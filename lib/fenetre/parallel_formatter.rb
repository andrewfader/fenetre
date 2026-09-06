# frozen_string_literal: true

module Fenetre
  module TestFormatter
    module COLORS
      RESET = "\e[0m"
      BOLD = "\e[1m"
      RED = "\e[31m"
      GREEN = "\e[32m"
      YELLOW = "\e[33m"
      BLUE = "\e[34m"
      MAGENTA = "\e[35m"
      CYAN = "\e[36m"
      WHITE = "\e[37m"
    end
  end

  class ParallelFormatter
    attr_reader :output

    def initialize(output = $stdout)
      @output = output
    end
  end
end
