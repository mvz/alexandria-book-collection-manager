# frozen_string_literal: true

# Copyright (C) 2007 Cathal Mc Ginley
# Copyright (C) 2011 Matijs van Zuijlen
#
# Alexandria is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with Alexandria; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301 USA.

require "logger"
require "forwardable"

module Alexandria
  # A Logger subclass which accepts a source for log messages
  # in order to improve legibility of the logs.
  # The source should usually be +self+, whether that be a Class, Module
  # or Object. A LogWrapper can be used to simplify this procedure.
  class Logger < ::Logger
    def add(severity, message = nil, source = nil, progname = nil, &block)
      return super(severity, message, progname, &block) if source.nil?

      category = self.class.category(source)
      return super(severity, progname, category) unless block

      category = "#{category} #{progname}" if progname
      super(severity, message, category, &block)
    end

    def debug(source = nil, progname = nil, &)
      add(DEBUG, nil, source, progname, &)
    end

    def info(source = nil, progname = nil, &)
      add(INFO, nil, source, progname, &)
    end

    def warn(source = nil, progname = nil, &)
      add(WARN, nil, source, progname, &)
    end

    def error(source = nil, progname = nil, &)
      add(ERROR, nil, source, progname, &)
    end

    def fatal(source = nil, progname = nil, &)
      add(FATAL, nil, source, progname, &)
    end

    def self.category(source)
      if source.instance_of? Class
        "[Cls  #{source.name}]"
      elsif source.instance_of? Module
        "[Mod #{source.name}]"
      else
        "<Obj #{source.class.name}>"
      end
    end
  end

  # A wrapper around a Logger, which allows code to define the source
  # once (in the wrapper's initialization) and then call the log methods
  # whithout needing to specify the source each time.
  class LogWrapper
    extend Forwardable

    def initialize(logger, source)
      @logger = logger
      @source = source
    end

    def_delegators :@logger, :debug?, :info?, :warn?, :error?, :fatal?

    def <<(msg)
      if msg.respond_to? :backtrace
        msg.backtrace.each do |line|
          @logger << "  #{line} \n"
        end
      else
        @logger << msg + "\n"
      end
    end

    def debug(progname = nil, &)
      @logger.debug(@source, progname, &)
    end

    def info(progname = nil, &)
      @logger.info(@source, progname, &)
    end

    def warn(progname = nil, &)
      @logger.warn(@source, progname, &)
    end

    def error(progname = nil, &)
      @logger.error(@source, progname, &)
    end

    def fatal(progname = nil, &)
      @logger.fatal(@source, progname, &)
    end
  end

  # A mixin to include a +log+ instance method for objects or a
  # static +log+ method for classes and modules. In either case, a
  # +LogWrapper+ is returned which wraps the Alexandria log and
  # specifies the appropriate source object, class or module.
  module Logging
    module ClassMethods
      def log
        @log ||= LogWrapper.new(Alexandria.log, self)
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def log
      @log ||= LogWrapper.new(Alexandria.log, self)
    end
  end

  # Creates the Logger for Alexandria
  def self.create_logger
    logger = Alexandria::Logger.new($stderr)

    level = ENV["LOGLEVEL"]&.intern
    if [:FATAL, :ERROR, :WARN, :INFO, :DEBUG].include? level
      logger.level = Logger.const_get(level)
    else
      logger.level = Logger::WARN # default level
      logger.warn(self, "Unknown LOGLEVEL '#{level}'; using WARN") if level
    end

    logger
  end

  @@logger = create_logger

  # Returns the Logger for Alexandria
  def self.log
    @@logger
  end
end
