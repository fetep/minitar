# coding: utf-8

require 'archive/tar/minitar/writer'

module Archive
  module Tar
    module Minitar
      # Wraps a Archive::Tar::Minitar::Writer with convenience methods and
      # wrapped stream management.
      #
      # If the stream provided to Output does not support random access, only
      # Writer#add_file_simple and Writer#mkdir are guaranteed to work.
      class Output
        # With no associated block, +Output.open+ is a synonym for
        # +Output.new+. If the optional code block is given, it will be given
        # the new Output as an argument and the Output object will
        # automatically be closed when the block terminates (this also closes
        # the wrapped stream object). In this instance, +Output.open+ returns
        # the value of the block.
        #
        # call-seq:
        #    Archive::Tar::Minitar::Output.open(io) -> output
        #    Archive::Tar::Minitar::Output.open(io) { |output| block } -> obj
        def self.open(output)
          stream = new(output)
          return stream unless block_given?

          begin
            res = yield stream
          ensure
            stream.close
          end

          res
        end

        # Creates a new Output object. If +output+ is a stream object that
        # responds to #write, then it will simply be wrapped. Otherwise, one
        # will be created and opened using Kernel#open. When Output#close is
        # called, the stream object wrapped will be closed.
        #
        # call-seq:
        #    Archive::Tar::Minitar::Output.new(io) -> output
        #    Archive::Tar::Minitar::Output.new(path) -> output
        def initialize(output)
          if output.respond_to?(:write)
            @io = output
          else
            @io = ::File.open(output, "wb")
          end
          @tar = Archive::Tar::Minitar::Writer.new(@io)
        end

        # Returns the Writer object for direct access.
        attr_reader :tar

        # Closes the Writer object and the wrapped data stream.
        def close
          @tar.close
          @io.close
        end
      end
    end
  end
end
